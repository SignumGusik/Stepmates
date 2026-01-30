from django.db.models import Q
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from .models import FriendRequest, Friendship
from .serializers import (
    UserShortSerializer,
    FriendRequestSerializer,
    CreateFriendRequestSerializer,
)

from django.core.exceptions import ValidationError
from django.core.validators import EmailValidator
from django.contrib.auth import get_user_model
from django.db.utils import IntegrityError
from django.views.generic import TemplateView
from django.http.response import JsonResponse

from rest_framework.response import Response
from rest_framework.generics import GenericAPIView
from rest_framework.permissions import AllowAny
from rest_framework import status

from . import utils

USER_MODEL = get_user_model()


class RegisterAppUser(GenericAPIView):
    permission_classes = [AllowAny]

    def post(self, request):
        if 'email' in request.data:
            email = request.data['email']
        else:
            email = None
        password = request.data.get('password', None)
        confirm_password = request.data.get('password2', None)

        if email is None or password is None or confirm_password is None:
            return Response('Missing Data', status=status.HTTP_400_BAD_REQUEST)

        data_validation_errors = []
        if password != confirm_password:
            data_validation_errors.append("Password fields don't match")
        try:
            validator = EmailValidator()
            validator(email)
        except ValidationError as e:
            print(e)
            data_validation_errors.append(e.messages)

        if len(data_validation_errors) > 0:
            return Response(data_validation_errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = USER_MODEL.objects.create_user(
                username=email,
                email=email,
                password=password,
                is_active=False
            )
        except IntegrityError:
            return Response(f'User {email} already exists')

        success = utils.send_activation_email(user)

        if not success:
            return Response('Could not send email', status=status.HTTP_400_BAD_REQUEST)
        return Response(f'Success. An activation email has been sent to: {email}', status=status.HTTP_201_CREATED)

class ActivateAccount(TemplateView):
    template_name = 'api/account_activation.html'

    def get(self, request, *args, **kwargs):
        context = self.get_context_data(**kwargs)
        token = kwargs['token']

        if not token or not utils.is_token_valid(token):
            context['failed_reason'] = 'Token Invalid or Missing'
            return self.render_to_response(context)
        try:
            user = utils.get_user_from_token(token)
            utils.revoke_token(token)
        except USER_MODEL.DoesNotExist:
            context['failed_reason'] = 'User does not exist'
            return self.render_to_response(context)

        user.is_active = True
        user.save()

        return self.render_to_response(context)


class LoginDataApi(GenericAPIView):
    def get(self, request):
        data = {
            'message': 'You are logged in!'
        }

        return JsonResponse(data, safe=False, status=status.HTTP_200_OK)

class UserSearchApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        q = (request.query_params.get("q") or "").strip()
        qs = USER_MODEL.objects.all()

        if q:
            qs = qs.filter(
                Q(username__icontains=q)
                | Q(email__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
            )

        qs = qs.exclude(id=request.user.id).order_by("id")[:50]
        me_id = request.user.id

        friend_pairs = Friendship.objects.filter(Q(user1_id=me_id) | Q(user2_id=me_id)) \
                                         .values_list("user1_id", "user2_id")
        friends_ids = set()
        for u1, u2 in friend_pairs:
            friends_ids.add(u2 if u1 == me_id else u1)

        sent_pending_ids = set(
            FriendRequest.objects.filter(from_user_id=me_id, status="pending")
            .values_list("to_user_id", flat=True)
        )
        received_pending_ids = set(
            FriendRequest.objects.filter(to_user_id=me_id, status="pending")
            .values_list("from_user_id", flat=True)
        )

        ser = UserShortSerializer(
            qs,
            many=True,
            context={
                "request": request,
                "friends_ids": friends_ids,
                "sent_pending_ids": sent_pending_ids,
                "received_pending_ids": received_pending_ids,
            },
        )
        return Response(ser.data, status=status.HTTP_200_OK)


class FriendRequestCreateApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = CreateFriendRequestSerializer

    def post(self, request):
        s = self.get_serializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)

        to_user_id = s.validated_data["to_user_id"]
        fr = FriendRequest.objects.create(
            from_user=request.user,
            to_user_id=to_user_id,
            status="pending"
        )
        return Response(FriendRequestSerializer(fr, context={"request": request}).data,
                        status=status.HTTP_201_CREATED)


class IncomingFriendRequestsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = FriendRequest.objects.filter(to_user=request.user, status="pending") \
                                  .select_related("from_user", "to_user") \
                                  .order_by("-created_at")
        return Response(FriendRequestSerializer(qs, many=True, context={"request": request}).data)


class OutgoingFriendRequestsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = FriendRequest.objects.filter(from_user=request.user, status="pending") \
                                  .select_related("from_user", "to_user") \
                                  .order_by("-created_at")
        return Response(FriendRequestSerializer(qs, many=True, context={"request": request}).data)


class AcceptFriendRequestApi(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk: int):
        try:
            fr = FriendRequest.objects.select_related("from_user", "to_user").get(id=pk)
        except FriendRequest.DoesNotExist:
            return Response({"detail": "Заявка не найдена."}, status=status.HTTP_404_NOT_FOUND)

        if fr.to_user_id != request.user.id:
            return Response({"detail": "Нельзя принять чужую заявку."}, status=status.HTTP_403_FORBIDDEN)
        if fr.status != "pending":
            return Response({"detail": "Заявка уже обработана."}, status=status.HTTP_400_BAD_REQUEST)

        a, b = Friendship.make_pair(fr.from_user_id, fr.to_user_id)
        Friendship.objects.get_or_create(user1_id=a, user2_id=b)

        fr.status = "accepted"
        fr.save(update_fields=["status"])

        return Response(FriendRequestSerializer(fr, context={"request": request}).data,
                        status=status.HTTP_200_OK)


class RejectFriendRequestApi(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk: int):
        try:
            fr = FriendRequest.objects.get(id=pk)
        except FriendRequest.DoesNotExist:
            return Response({"detail": "Заявка не найдена."}, status=status.HTTP_404_NOT_FOUND)

        if fr.to_user_id != request.user.id:
            return Response({"detail": "Нельзя отклонить чужую заявку."}, status=status.HTTP_403_FORBIDDEN)
        if fr.status != "pending":
            return Response({"detail": "Заявка уже обработана."}, status=status.HTTP_400_BAD_REQUEST)

        fr.status = "rejected"
        fr.save(update_fields=["status"])
        return Response(FriendRequestSerializer(fr, context={"request": request}).data,
                        status=status.HTTP_200_OK)


class FriendsListApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        me_id = request.user.id
        pairs = Friendship.objects.filter(Q(user1_id=me_id) | Q(user2_id=me_id)) \
                                  .values_list("user1_id", "user2_id")

        ids = set()
        for u1, u2 in pairs:
            ids.add(u2 if u1 == me_id else u1)

        qs = USER_MODEL.objects.filter(id__in=ids).order_by("id")

        ser = UserShortSerializer(
            qs,
            many=True,
            context={
                "request": request,
                "friends_ids": ids,
                "sent_pending_ids": set(),
                "received_pending_ids": set(),
            },
        )
        return Response(ser.data, status=status.HTTP_200_OK)


class RemoveFriendApi(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, user_id: int):
        if user_id == request.user.id:
            return Response({"detail": "Нельзя удалить самого себя."}, status=status.HTTP_400_BAD_REQUEST)

        a, b = Friendship.make_pair(request.user.id, user_id)
        deleted, _ = Friendship.objects.filter(user1_id=a, user2_id=b).delete()

        if deleted == 0:
            return Response({"detail": "Вы не друзья."}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)


