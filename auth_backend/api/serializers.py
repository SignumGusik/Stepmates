from django.contrib.auth import get_user_model, authenticate
from rest_framework import serializers
from django.utils import timezone
import re

from .models import FriendRequest, Friendship, Group, GroupMembership, DailySteps

from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class UserShortSerializer(serializers.ModelSerializer):
    is_friend = serializers.SerializerMethodField()
    request_sent = serializers.SerializerMethodField()
    request_received = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "is_friend",
            "request_sent",
            "request_received",
        )

    def _ctx_set(self, key: str):
        s = self.context.get(key)
        return s if isinstance(s, set) else set()

    def get_is_friend(self, obj):
        return obj.id in self._ctx_set("friends_ids")

    def get_request_sent(self, obj):
        return obj.id in self._ctx_set("sent_pending_ids")

    def get_request_received(self, obj):
        return obj.id in self._ctx_set("received_pending_ids")


class FriendRequestSerializer(serializers.ModelSerializer):
    from_user = UserShortSerializer(read_only=True)
    to_user = UserShortSerializer(read_only=True)

    class Meta:
        model = FriendRequest
        fields = ("id", "from_user", "to_user", "status", "created_at")


class CreateFriendRequestSerializer(serializers.Serializer):
    to_user_id = serializers.IntegerField()

    def validate_to_user_id(self, value):
        request = self.context["request"]
        if value == request.user.id:
            raise serializers.ValidationError("Нельзя отправить заявку самому себе.")
        if not User.objects.filter(id=value).exists():
            raise serializers.ValidationError("Пользователь не найден.")
        return value

    def validate(self, attrs):
        request = self.context["request"]
        me = request.user
        to_user_id = attrs["to_user_id"]

        a, b = Friendship.make_pair(me.id, to_user_id)
        if Friendship.objects.filter(user1_id=a, user2_id=b).exists():
            raise serializers.ValidationError("Вы уже друзья.")

        if FriendRequest.objects.filter(from_user=me, to_user_id=to_user_id, status="pending").exists():
            raise serializers.ValidationError("Заявка уже отправлена и ожидает ответа.")

        if FriendRequest.objects.filter(from_user_id=to_user_id, to_user=me, status="pending").exists():
            raise serializers.ValidationError("У вас уже есть входящая заявка от этого пользователя.")

        return attrs


class GroupCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Group
        fields = ["id", "name", "description", "created_at"]


class GroupListSerializer(serializers.ModelSerializer):
    is_admin = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ["id", "name", "description", "created_at", "is_admin"]

    def get_is_admin(self, obj):
        user = self.context["request"].user
        m = obj.memberships.filter(user=user).only("is_admin").first()
        return bool(m and m.is_admin)


class GroupMemberSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source="user.id")
    username = serializers.CharField(source="user.username")
    email = serializers.CharField(source="user.email")
    first_name = serializers.CharField(source="user.first_name", allow_blank=True)
    last_name = serializers.CharField(source="user.last_name", allow_blank=True)

    class Meta:
        model = GroupMembership
        fields = ["id", "username", "email", "first_name", "last_name", "is_admin", "created_at"]


class GroupDetailSerializer(serializers.ModelSerializer):
    members = serializers.SerializerMethodField()
    my_is_admin = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ["id", "name", "description", "created_at", "members", "my_is_admin"]

    def get_members(self, obj):
        qs = obj.memberships.select_related("user").order_by("-is_admin", "user__username")
        return GroupMemberSerializer(qs, many=True).data

    def get_my_is_admin(self, obj):
        user = self.context["request"].user
        m = obj.memberships.filter(user=user).only("is_admin").first()
        return bool(m and m.is_admin)


class AddMemberSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError({"password2": "Пароли не совпадают."})
        return attrs

class PasswordResetVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value

class DailyStepsSyncSerializer(serializers.Serializer):
    steps = serializers.IntegerField(min_value=0)
    date = serializers.DateField(required=False)

    def validate_date(self, value):
        if value > timezone.localdate():
            raise serializers.ValidationError("Нельзя отправить шаги из будущего.")
        return value


class DailyStepsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = DailySteps
        fields = ["id", "username", "date", "steps", "updated_at"]


class FriendLeaderboardSerializer(serializers.Serializer):
    place = serializers.IntegerField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    steps = serializers.IntegerField()
    is_me = serializers.BooleanField()

class RegisterVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class RegisterResendSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class SetUsernameSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=30)

    def validate_username(self, value):
        value = value.strip()

        if not re.fullmatch(r"[A-Za-z0-9_]+", value):
            raise serializers.ValidationError(
                "Никнейм может содержать только латинские буквы, цифры и _"
            )

        request = self.context["request"]

        if User.objects.filter(username__iexact=value).exclude(id=request.user.id).exists():
            raise serializers.ValidationError("Этот никнейм уже занят.")

        return value

class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = "email"

    email = serializers.EmailField(write_only=True)
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs.get("email")
        password = attrs.get("password")

        if not email or not password:
            raise serializers.ValidationError("Введите email и пароль.")

        user = User.objects.filter(email__iexact=email).first()
        if user is None:
            raise serializers.ValidationError("Пользователь не найден.")

        auth_user = authenticate(username=user.username, password=password)
        if auth_user is None:
            if not user.is_active:
                raise serializers.ValidationError("Аккаунт не активирован.")
            raise serializers.ValidationError("Неверный пароль.")

        refresh = self.get_token(auth_user)

        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": {
                "id": auth_user.id,
                "email": auth_user.email,
                "username": auth_user.username,
            }
        }