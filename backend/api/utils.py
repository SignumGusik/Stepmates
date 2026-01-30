from django.conf import settings
from django.core.mail import send_mail
from django.urls import reverse
from django.core.exceptions import ValidationError

from django.contrib.auth import get_user_model
from smtplib import  SMTPException

from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError

from .tokens import BlacklistableAccessToken

USER_MODEL = get_user_model()


def send_activation_email(user):
  if user.email is None:
    return False
  oauth_token = AccessToken.for_user(user)
  link = settings.SERVER_BASE_URL + reverse('api:user_activation', kwargs={'token': oauth_token})

  try:
    send_mail(
      from_email=settings.EMAIL_HOST_USER,
      subject='Activate your new account',
      recipient_list=[user.email],
      message='',
      html_message='<p>Please click the link below to activate your account.</p><br/><br/>'
                   '<a href="' + link + '">' + link + '</a>',
      fail_silently=False
    )
  except SMTPException as e:
    print(e)
    return False
  return True

def get_user_from_token(token):
  try:
    access_token = AccessToken(token)
    user_id = access_token['user_id']
    return USER_MODEL.objects.get(id=user_id)
  except USER_MODEL.DoesNotExist as e:
    print(e)
    raise ValidationError('User does not exist')
  except Exception as e:
    raise ValidationError(f'Could not decode token: {e}')


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