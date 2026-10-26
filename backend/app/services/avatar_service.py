import io
import logging
import threading
from collections import OrderedDict
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError

from app.config import settings
from app.db import get_db

logger = logging.getLogger(__name__)

Image.MAX_IMAGE_PIXELS = 24_000_000

AVATAR_SIZES = (64, 256)
MAX_AVATAR_BYTES = 8 * 1024 * 1024
_CACHE_LIMIT = 500


class AvatarError(Exception):
    pass


class AvatarService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._cache: OrderedDict[tuple[int, int, int], bytes] = OrderedDict()

    def root(self) -> Path:
        configured = settings.avatar_dir.strip()
        path = Path(configured) if configured else Path(__file__).resolve().parents[2] / "data" / "avatars"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def version_of(self, user_id: int) -> int | None:
        with get_db() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT avatar_version FROM users WHERE id = %s",
                    (user_id,),
                )
                row = cursor.fetchone()
        if not row:
            return None
        version = row.get("avatar_version")
        return int(version) if version is not None else None

    def read(self, user_id: int, size: int) -> tuple[int, bytes] | None:
        size = 256 if size >= 128 else 64
        version = self.version_of(user_id)
        if version is None:
            return None

        key = (user_id, version, size)
        with self._lock:
            cached = self._cache.get(key)
            if cached is not None:
                self._cache.move_to_end(key)
                return version, cached

        path = self._path(user_id, size)
        if not path.is_file():
            return None
        data = path.read_bytes()
        with self._lock:
            self._cache[key] = data
            self._cache.move_to_end(key)
            while len(self._cache) > _CACHE_LIMIT:
                self._cache.popitem(last=False)
        return version, data

    def save(self, user_id: int, data: bytes) -> None:
        if not data:
            raise AvatarError("Файл пустой")
        if len(data) > MAX_AVATAR_BYTES:
            raise AvatarError("Файл слишком большой")

        encoded = _encode_sizes(data)
        user_dir = self.root() / str(user_id)
        user_dir.mkdir(parents=True, exist_ok=True)
        for size, payload in encoded.items():
            _atomic_write(user_dir / f"{size}.webp", payload)
        self._drop_user(user_id)

    def delete(self, user_id: int) -> None:
        user_dir = self.root() / str(user_id)
        if user_dir.exists():
            for path in user_dir.glob("*.webp"):
                path.unlink(missing_ok=True)
            try:
                user_dir.rmdir()
            except OSError:
                pass
        self._drop_user(user_id)

    def _path(self, user_id: int, size: int) -> Path:
        return self.root() / str(user_id) / f"{size}.webp"

    def _drop_user(self, user_id: int) -> None:
        with self._lock:
            for key in [key for key in self._cache if key[0] == user_id]:
                self._cache.pop(key, None)


def _encode_sizes(data: bytes) -> dict[int, bytes]:
    try:
        with Image.open(io.BytesIO(data)) as image:
            image = ImageOps.exif_transpose(image)
            if image.mode != "RGB":
                image = image.convert("RGB")
            side = min(image.size)
            if side < 8:
                raise AvatarError("Изображение слишком маленькое")
            left = (image.width - side) // 2
            top = (image.height - side) // 2
            square = image.crop((left, top, left + side, top + side))
            encoded: dict[int, bytes] = {}
            for size in AVATAR_SIZES:
                thumb = square.copy()
                thumb.thumbnail((size, size), Image.Resampling.LANCZOS)
                buffer = io.BytesIO()
                thumb.save(buffer, format="WEBP", quality=80 if size >= 256 else 72, method=4)
                encoded[size] = buffer.getvalue()
            return encoded
    except AvatarError:
        raise
    except (UnidentifiedImageError, OSError, ValueError) as error:
        logger.info("Rejected avatar upload: %s", error)
        raise AvatarError("Нужен файл изображения") from error


def _atomic_write(path: Path, data: bytes) -> None:
    temporary = path.with_suffix(".webp.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


avatar_service = AvatarService()
