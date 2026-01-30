from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import FriendRequest, Friendship

User = get_user_model()


class UserShortSerializer(serializers.ModelSerializer):
    is_friend = serializers.SerializerMethodField()
    request_sent = serializers.SerializerMethodField()
    request_received = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "username", "email", "first_name", "last_name",
                  "is_friend", "request_sent", "request_received")

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