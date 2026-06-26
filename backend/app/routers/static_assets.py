import logging
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response

logger = logging.getLogger(__name__)

router = APIRouter()

_ALLOWED_SCHEMES = {"http", "https"}
_MAX_IMAGE_BYTES = 20 * 1024 * 1024
_USER_AGENT = "DDT/1.0"


@router.get("/image-proxy")
async def image_proxy(url: str = Query(..., min_length=8)) -> Response:
    parsed = urlparse(url)
    if parsed.scheme not in _ALLOWED_SCHEMES or not parsed.netloc:
        raise HTTPException(status_code=400, detail="Invalid image URL")

    request = Request(url, headers={"User-Agent": _USER_AGENT})

    try:
        with urlopen(request, timeout=20) as response:
            content_type = response.headers.get("Content-Type", "image/jpeg")
            if not content_type.startswith("image/"):
                raise HTTPException(
                    status_code=400,
                    detail="URL does not point to an image",
                )

            data = response.read(_MAX_IMAGE_BYTES + 1)
            if len(data) > _MAX_IMAGE_BYTES:
                raise HTTPException(status_code=413, detail="Image is too large")
    except HTTPError as error:
        logger.warning("Image proxy HTTP error for %s: %s", url, error)
        raise HTTPException(
            status_code=error.code,
            detail="Failed to fetch image",
        ) from error
    except URLError as error:
        logger.warning("Image proxy network error for %s: %s", url, error)
        raise HTTPException(
            status_code=502,
            detail="Failed to fetch image",
        ) from error

    return Response(
        content=data,
        media_type=content_type.split(";", 1)[0].strip(),
        headers={
            "Cache-Control": "public, max-age=86400",
            "Access-Control-Allow-Origin": "*",
        },
    )
