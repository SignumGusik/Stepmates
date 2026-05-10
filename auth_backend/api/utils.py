from datetime import timedelta
from random import randint
import random
from smtplib import SMTPException

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.urls import reverse
from django.utils import timezone
from django.contrib.auth import get_user_model

from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError

from .models import PasswordResetCode, EmailVerificationCode
from .tokens import BlacklistableAccessToken

USER_MODEL = get_user_model()


def send_activation_email(user):
    if user.email is None:
        return False

    oauth_token = AccessToken.for_user(user)
    link = settings.SERVER_BASE_URL + reverse("api:user_activation", kwargs={"token": oauth_token})

    try:
        send_mail(
            from_email=settings.EMAIL_HOST_USER,
            subject="Activate your new account",
            recipient_list=[user.email],
            message="",
            html_message=(
                '<p>Please click the link below to activate your account.</p><br/><br/>'
                f'<a href="{link}">{link}</a>'
            ),
            fail_silently=False,
        )
    except SMTPException as e:
        print(e)
        return False

    return True


def generate_reset_code():
    return f"{randint(0, 999999):06d}"


def create_password_reset_code(user):
    PasswordResetCode.objects.filter(user=user, is_used=False).delete()

    code = generate_reset_code()
    expires_at = timezone.now() + timedelta(minutes=10)

    reset_code = PasswordResetCode.objects.create(
        user=user,
        code=code,
        expires_at=expires_at,
    )
    return reset_code


def send_password_reset_email(user):
    if user.email is None:
        print("NO EMAIL")
        return False

    reset_code = create_password_reset_code(user)

    try:
        send_mail(
            subject="Reset your password",
            message=f"Your password reset code: {reset_code.code}",
            from_email=settings.EMAIL_HOST_USER,
            recipient_list=[user.email],
            html_message=(
                f"<p>Your password reset code:</p>"
                f"<h2>{reset_code.code}</h2>"
                f"<p>The code is valid for 10 minutes.</p>"
            ),
            fail_silently=False,
        )
        print("EMAIL SENT OK")
        return True
    except Exception as e:
        print("EMAIL ERROR:", repr(e))
        return False


def get_valid_password_reset_code(email, code):
    user = USER_MODEL.objects.filter(email__iexact=email).first()
    if not user:
        raise ValidationError("Пользователь не найден.")

    reset_code = PasswordResetCode.objects.filter(
        user=user,
        code=code,
        is_used=False,
    ).order_by("-created_at").first()

    if not reset_code:
        raise ValidationError("Неверный код.")

    if reset_code.is_expired():
        raise ValidationError("Код истёк.")

    return user, reset_code


def get_user_from_token(token):
    try:
        access_token = AccessToken(token)
        user_id = access_token["user_id"]
        return USER_MODEL.objects.get(id=user_id)
    except USER_MODEL.DoesNotExist as e:
        print(e)
        raise ValidationError("User does not exist")
    except Exception as e:
        raise ValidationError(f"Could not decode token: {e}")


def revoke_token(token):
    token = BlacklistableAccessToken(token)
    token.blacklist()


def is_token_valid(token):
    access_token = BlacklistableAccessToken(token)
    try:
        access_token.check_exp()
        access_token.check_blacklist()
        return True
    except TokenError as e:
        print(e)
        return False

def generate_email_verification_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def create_email_verification_code(user):
    EmailVerificationCode.objects.filter(user=user, is_used=False).update(is_used=True)

    code = generate_email_verification_code()
    return EmailVerificationCode.objects.create(
        user=user,
        code=code,
        expires_at=timezone.now() + timedelta(minutes=10),
    )


def send_registration_code_email(user):
    verification = create_email_verification_code(user)

    if getattr(settings, "DISABLE_EMAIL", False):
        print("====================================")
        print(f"REGISTRATION CODE for {user.email}: {verification.code}")
        print("====================================")
        return True

    subject = "Код подтверждения регистрации"
    message = f"Ваш код подтверждения: {verification.code}"

    try:
        send_mail(
            subject=subject,
            message=message,
            from_email=settings.EMAIL_HOST_USER,
            recipient_list=[user.email],
            fail_silently=False,
        )
        return True
    except Exception as e:
        print("REGISTRATION EMAIL ERROR:", repr(e))
        return False


def get_valid_registration_code(email, code):
    user = USER_MODEL.objects.get(email__iexact=email)

    verification = EmailVerificationCode.objects.filter(
        user=user,
        code=code,
        is_used=False
    ).order_by("-created_at").first()

    if verification is None:
        raise ValidationError("Неверный код.")

    if verification.is_expired():
        raise ValidationError("Срок действия кода истёк.")

    return user, verification

def _avatar_url(request, user):

    profile = getattr(user, "profile", None)

    if not profile or not profile.avatar:

        return None

    return request.build_absolute_uri(profile.avatar.url)
