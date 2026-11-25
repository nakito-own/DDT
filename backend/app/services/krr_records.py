"""Колонки набора «Версии работ КРР МР» и разбор строки ответа DTW."""

from dataclasses import dataclass
from datetime import date, datetime

# API field `id` is stored as source_id. The two numeric-prefixed keys cannot
# be column names, so they are stored as ref_13048_id and ref_13049_id.
@dataclass(frozen=True)
class Field:
    column: str
    key: str
    kind: str
    size: int = 0


FIELDS: tuple[Field, ...] = (
    Field("id_unique", "id_unique", "int"),
    Field("name_work_version", "name_work_version", "str", 512),
    Field("id_work", "id_work", "int"),
    Field("source_id", "id", "int"),
    Field("object_id", "object_id", "str", 64),
    Field("name", "name", "str", 512),
    Field("type_object", "type_object", "str", 255),
    Field("type_object_code", "type_object_code", "int"),
    Field("category_object_id", "category_object_id", "int"),
    Field("category_object_name", "category_object_name", "str", 255),
    Field("subcategory_object_id", "subcategory_object_id", "str", 64),
    Field("subcategory_object_name", "subcategory_object_name", "str", 255),
    Field("adm_district", "adm_district", "str", 64),
    Field("district", "district", "str", 128),
    Field("address", "address", "text"),
    Field("work_date", "work_date", "str", 32),
    Field("stage", "stage", "str", 128),
    Field("link", "link", "str", 512),
    Field("dk", "dk", "bool"),
    Field("category_object", "category_object", "str", 255),
    Field("plan_start_date_epoch", "plan_start_date_epoch", "float"),
    Field("plan_end_date_epoch", "plan_end_date_epoch", "float"),
    Field("fact_start_date_epoch", "fact_start_date_epoch", "float"),
    Field("fact_end_date_epoch", "fact_end_date_epoch", "float"),
    Field("work_year_epoch", "work_year_epoch", "float"),
    Field("pir_plan_start_date_epoch", "pir_plan_start_date_epoch", "float"),
    Field("pir_plan_end_date_epoch", "pir_plan_end_date_epoch", "float"),
    Field("pir_fact_start_date_epoch", "pir_fact_start_date_epoch", "float"),
    Field("pir_fact_end_date_epoch", "pir_fact_end_date_epoch", "float"),
    Field("smr_plan_start_date_epoch", "smr_plan_start_date_epoch", "float"),
    Field("smr_plan_end_date_epoch", "smr_plan_end_date_epoch", "float"),
    Field("smr_fact_start_date_epoch", "smr_fact_start_date_epoch", "float"),
    Field("smr_fact_end_date_epoch", "smr_fact_end_date_epoch", "float"),
    Field("fact_start_date", "fact_start_date", "date"),
    Field("fact_end_date", "fact_end_date", "date"),
    Field("plan_start_date", "plan_start_date", "date"),
    Field("plan_end_date", "plan_end_date", "date"),
    Field("square_formatted", "square_formatted", "str", 64),
    Field("kind_group_id", "kind_group_id", "str", 32),
    Field("stage_id", "stage_id", "int"),
    Field("square", "square", "float"),
    Field("work_date_id", "work_date_id", "int"),
    Field("work_date_id1", "work_date_id1", "int"),
    Field("work_year", "work_year", "int"),
    Field("load_status", "load_status", "str", 255),
    Field("pir_date_plan_beg", "pir_date_plan_beg", "date"),
    Field("smr_date_plan_beg", "smr_date_plan_beg", "date"),
    Field("pir_date_plan_end", "pir_date_plan_end", "date"),
    Field("smr_date_plan_end", "smr_date_plan_end", "date"),
    Field("pir_date_fact_beg", "pir_date_fact_beg", "date"),
    Field("pir_date_fact_end", "pir_date_fact_end", "date"),
    Field("smr_date_fact_beg", "smr_date_fact_beg", "date"),
    Field("smr_date_fact_end", "smr_date_fact_end", "date"),
    Field("category_event", "category_event", "str", 255),
    Field("id_category_event", "id_category_event", "int"),
    Field("customer_pir", "customer_pir", "str", 512),
    Field("customer_smr", "customer_smr", "str", 512),
    Field("id_customer_pir", "id_customer_pir", "str", 64),
    Field("id_customer_smr", "id_customer_smr", "str", 64),
    Field("id_version_ogh", "id_version_ogh", "str", 64),
    Field("id_ogh", "id_ogh", "str", 64),
    Field("activation_status", "activation_status", "str", 255),
    Field("program", "program", "str", 255),
    Field("program_id", "program_id", "str", 64),
    Field("address_bti", "address_bti", "text"),
    Field("version", "version", "str", 128),
    Field("date_archive", "date_archive", "date"),
    Field("date_change", "date_change", "date"),
    Field("date_creation", "date_creation", "date"),
    Field("inn_contractor", "inn_contractor", "str", 32),
    Field("contractor", "contractor", "str", 512),
    Field("footing", "footing", "str", 255),
    Field("reason_cansel", "reason_cansel", "text"),
    Field("nature_of_the_work_smr", "nature_of_the_work_smr", "text"),
    Field("type_sys", "type_sys", "str", 255),
    Field("type_sys_id", "type_sys_id", "int"),
    Field("status_id", "status_id", "int"),
    Field("finance", "finance", "str", 255),
    Field("departmental_oiv_id", "departmental_oiv_id", "str", 64),
    Field("departmental_oiv_class", "departmental_oiv_class", "int"),
    Field("departmental_oiv_class_name", "departmental_oiv_class_name", "str", 255),
    Field("status_id_name", "status_id_name", "str", 255),
    Field("customer", "customer", "str", 512),
    Field("balance_holder", "balance_holder", "str", 512),
    Field("departmental_oiv", "departmental_oiv", "str", 512),
    Field("geometry_valid", "geometry_valid", "bool"),
    Field("geometry_invalid_reason", "geometry_invalid_reason", "text"),
    Field("okrug_id", "okrug_id", "str", 32),
    Field("raion_id", "raion_id", "str", 32),
    Field("cpgz_names", "cpgz_names", "text"),
    Field("created_date_work", "created_date_work", "date"),
    Field("changed_data_work", "changed_data_work", "date"),
    Field("created_date_version", "created_date_version", "date"),
    Field("changed_date_version", "changed_date_version", "date"),
    Field("ref_13048_id", "13048_id_unique", "str", 64),
    Field("ref_13049_id", "13049_id_unique", "str", 64),
)

_DATE_FORMATS = ("%d.%m.%Y", "%Y-%m-%d")
_TRUE = {"true", "1", "yes", "да"}
_FALSE = {"false", "0", "no", "нет"}


def upsert_sql() -> str:
    columns = [field.column for field in FIELDS] + ["snapshot_date", "sync_generation"]
    assignments = ", ".join(
        f"{column} = new_row.{column}"
        for column in columns
        if column not in {"id_unique", "snapshot_date"}
    )
    names = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    return (
        f"INSERT INTO krr_work_versions ({names}) "
        f"VALUES ({placeholders}) AS new_row "
        f"ON DUPLICATE KEY UPDATE {assignments}, synced_at = CURRENT_TIMESTAMP"
    )


def dtw_attributes() -> str:
    """DTW wants attributes separated by a comma and a space, unencoded."""
    return ", ".join(field.key for field in FIELDS)


def encode_row(raw: dict, snapshot_date: date) -> tuple | None:
    if not isinstance(raw, dict):
        return None
    values = [_coerce(raw.get(field.key), field) for field in FIELDS]
    if values[0] is None:
        return None
    values.append(snapshot_date)
    return tuple(values)


def _coerce(value: object, field: Field) -> object:
    if field.kind == "int":
        return _as_int(value)
    if field.kind == "float":
        return _as_float(value)
    if field.kind == "bool":
        return _as_bool(value)
    if field.kind == "date":
        return _as_date(value)
    return _as_text(value, field.size)


def _as_text(value: object, size: int) -> str | None:
    if value is None:
        return None
    text = str(value).replace("\xa0", " ").strip()
    if not text:
        return None
    if size and len(text) > size:
        return text[:size]
    return text


def _as_int(value: object) -> int | None:
    if value is None or value is True or value is False or isinstance(value, bool):
        return int(value) if isinstance(value, bool) else None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value != value or value in {float("inf"), float("-inf")}:
            return None
        return int(value)
    text = str(value).strip()
    if not text:
        return None
    try:
        return int(float(text)) if "." in text else int(text)
    except ValueError:
        return None


def _as_float(value: object) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        number = float(value)
    else:
        text = str(value).strip().replace(" ", "").replace(",", ".")
        if not text:
            return None
        try:
            number = float(text)
        except ValueError:
            return None
    if number != number or number in {float("inf"), float("-inf")}:
        return None
    return number


def _as_bool(value: object) -> bool | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    text = str(value).strip().lower()
    if text in _TRUE:
        return True
    if text in _FALSE:
        return False
    return None


def _as_date(value: object) -> date | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value).strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None
