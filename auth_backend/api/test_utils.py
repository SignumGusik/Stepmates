from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone

from .models import EmailVerificationCode, PasswordResetCode
from .utils import (
    create_email_verification_code,
    create_password_reset_code,
    generate_email_verification_code,
    generate_reset_code,
    get_valid_password_reset_code,
    get_valid_registration_code,
    send_registration_code_email,
)

User = get_user_model()


class CodeGenerationTests(TestCase):
    def test_reset_code_is_six_digits(self):
        code = generate_reset_code()
        self.assertEqual(len(code), 6)
        self.assertTrue(code.isdigit())

    def test_email_verification_code_is_six_digits(self):
        code = generate_email_verification_code()
        self.assertEqual(len(code), 6)
        self.assertTrue(code.isdigit())


class PasswordResetUtilityTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="reset", email="reset@example.com", password="pass12345")

    def test_create_password_reset_code_replaces_previous_unused_codes(self):
        old = PasswordResetCode.objects.create(
            user=self.user,
            code="111111",
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        new = create_password_reset_code(self.user)

        self.assertFalse(PasswordResetCode.objects.filter(id=old.id).exists())
        self.assertEqual(PasswordResetCode.objects.filter(user=self.user, is_used=False).count(), 1)
        self.assertEqual(new.user, self.user)
        self.assertFalse(new.is_expired())

    def test_get_valid_password_reset_code_returns_user_and_code(self):
        reset_code = PasswordResetCode.objects.create(
            user=self.user,
            code="222222",
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        user, code = get_valid_password_reset_code("RESET@example.com", "222222")

        self.assertEqual(user, self.user)
        self.assertEqual(code, reset_code)

    def test_get_valid_password_reset_code_rejects_expired_code(self):
        PasswordResetCode.objects.create(
            user=self.user,
            code="333333",
            expires_at=timezone.now() - timedelta(minutes=1),
        )

        with self.assertRaises(ValidationError):
            get_valid_password_reset_code("reset@example.com", "333333")


class RegistrationCodeUtilityTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="register", email="register@example.com", password="pass12345")

    def test_create_email_verification_code_marks_previous_codes_used(self):
        first = create_email_verification_code(self.user)
        second = create_email_verification_code(self.user)

        first.refresh_from_db()
        self.assertTrue(first.is_used)
        self.assertFalse(second.is_used)
        self.assertEqual(EmailVerificationCode.objects.filter(user=self.user).count(), 2)

    def test_get_valid_registration_code_returns_user_and_code(self):
        verification = EmailVerificationCode.objects.create(
            user=self.user,
            code="444444",
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        user, code = get_valid_registration_code("REGISTER@example.com", "444444")

        self.assertEqual(user, self.user)
        self.assertEqual(code, verification)

    def test_get_valid_registration_code_rejects_used_code(self):
        EmailVerificationCode.objects.create(
            user=self.user,
            code="555555",
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=True,
        )

        with self.assertRaises(ValidationError):
            get_valid_registration_code("register@example.com", "555555")

    @override_settings(DISABLE_EMAIL=True)
    def test_send_registration_code_email_succeeds_when_email_disabled(self):
        self.assertTrue(send_registration_code_email(self.user))
        self.assertEqual(EmailVerificationCode.objects.filter(user=self.user).count(), 1)

    @override_settings(DISABLE_EMAIL=False, EMAIL_HOST_USER="noreply@example.com")
    @patch("api.utils.send_mail", return_value=1)
    def test_send_registration_code_email_uses_django_mail(self, send_mail):
        self.assertTrue(send_registration_code_email(self.user))
        send_mail.assert_called_once()
