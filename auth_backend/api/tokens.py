from rest_framework_simplejwt.tokens import BlacklistMixin, AccessToken

class BlacklistableAccessToken(AccessToken, BlacklistMixin):
  pass