import os
from datetime import datetime, timedelta

import pytz
from dotenv import load_dotenv
from exchangelib import Account, CalendarItem, Configuration, Credentials, DELEGATE

load_dotenv()

username = os.environ["EWS_USERNAME"]
password = os.environ["EWS_PASSWORD"]
email = os.environ["EWS_EMAIL"]
server = os.getenv("EWS_SERVER", "owa.mos.ru")

credentials = Credentials(username=username, password=password)

config = Configuration(
    server=server,
    credentials=credentials,
    auth_type=None,
)

account = Account(
    primary_smtp_address=email,
    config=config,
    autodiscover=False,
    access_type=DELEGATE,
)

print("=" * 60)
print("ТЕСТИРОВАНИЕ ДОСТУПА К EXCHANGE ЧЕРЕЗ EWS")
print("=" * 60)

print("\nИНФОРМАЦИЯ О ЯЩИКЕ")
print("-" * 40)
print(f"Владелец: {account.primary_smtp_address}")
print(f"Всего писем во Входящих: {account.inbox.total_count}")
print(f"Всего писем в Отправленных: {account.sent.total_count}")
print("Доступ к ящику подтверждён")

print("\nПОСЛЕДНИЕ 5 ПИСЕМ ИЗ ВХОДЯЩИХ")
print("-" * 40)
for i, item in enumerate(account.inbox.all().order_by("-datetime_received")[:5], 1):
    print(f"{i}. Тема: {item.subject}")
    print(f"   От: {item.sender}")
    print(f"   Дата: {item.datetime_received}")
    print("---")
print("Чтение почты работает")

print("\nКАЛЕНДАРЬ — ВСТРЕЧИ НА БЛИЖАЙШУЮ НЕДЕЛЮ")
print("-" * 40)
try:
    msk_tz = pytz.timezone(os.getenv("EWS_TIMEZONE", "Europe/Moscow"))
    today = datetime.now(msk_tz)
    next_week = today + timedelta(days=7)

    print(
        f"Поиск встреч с {today.strftime('%d.%m.%Y %H:%M')} "
        f"по {next_week.strftime('%d.%m.%Y %H:%M')}"
    )
    print()

    items = account.calendar.view(start=today, end=next_week)

    count = 0
    for item in items:
        if isinstance(item, CalendarItem):
            count += 1
            print(f"- {item.subject}")
            print(f"  Начало: {item.start.strftime('%d.%m.%Y %H:%M')}")
            print(f"  Конец: {item.end.strftime('%d.%m.%Y %H:%M')}")
            if item.location:
                print(f"  Место: {item.location}")
            if item.organizer:
                print(f"  Организатор: {item.organizer}")
            print("---")

    if count == 0:
        print("Нет встреч на ближайшую неделю")
    else:
        print(f"Всего встреч: {count}")

    print("Доступ к календарю подтверждён")
except Exception as exc:
    print(f"Ошибка доступа к календарю: {exc}")

print("\nКОНТАКТЫ")
print("-" * 40)
try:
    contact_folders = [
        account.contacts,
        account.root / "AllContacts",
        account.root / "RelevantContacts",
    ]

    all_contacts = []
    for folder in contact_folders:
        try:
            for contact in folder.all():
                all_contacts.append(contact)
        except Exception:
            pass

    if all_contacts:
        for i, contact in enumerate(all_contacts[:5], 1):
            print(f"{i}. {contact.display_name if contact.display_name else 'Без имени'}")
            if hasattr(contact, "email_addresses") and contact.email_addresses:
                for email_addr in contact.email_addresses:
                    print(f"   Email: {email_addr.email}")
            if hasattr(contact, "phone_numbers") and contact.phone_numbers:
                for phone in contact.phone_numbers[:2]:
                    print(f"   Телефон: {phone.phone_number}")
            print("---")
        print(f"Всего контактов: {len(all_contacts)}")
    else:
        print("Контакты отсутствуют во всех папках")

    print("Доступ к контактам подтверждён")
except Exception as exc:
    print(f"Ошибка доступа к контактам: {exc}")

print("\n" + "=" * 60)
print("ТЕСТИРОВАНИЕ ЗАВЕРШЕНО")
print("=" * 60)
