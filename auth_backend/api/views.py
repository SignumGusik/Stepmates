from django.db.models import Q
from django.core.exceptions import ValidationError
from django.core.validators import EmailValidator
from django.contrib.auth import get_user_model
from django.db.utils import IntegrityError
from django.views.generic import TemplateView
from django.http.response import JsonResponse
from django.db import transaction
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.generics import GenericAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import EmailTokenObtainPairSerializer
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from . import utils
from .models import FriendRequest, Friendship, Group, GroupMembership, GroupHidden, DailySteps, EmailVerificationCode
from .serializers import (
    UserShortSerializer,
    FriendRequestSerializer,
    CreateFriendRequestSerializer,
    GroupCreateSerializer,
    GroupListSerializer,
    GroupDetailSerializer,
    AddMemberSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetVerifySerializer,
    DailyStepsSyncSerializer,
    DailyStepsSerializer,
    FriendLeaderboardSerializer,
    RegisterVerifySerializer,
    RegisterResendSerializer,
    SetUsernameSerializer
)

USER_MODEL = get_user_model()


class RegisterAppUser(GenericAPIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email")
        password = request.data.get("password")
        confirm_password = request.data.get("password2")

        if email is None or password is None or confirm_password is None:
            print("REGISTER ERROR: missing data", email, password, confirm_password)
            return Response("Missing Data", status=status.HTTP_400_BAD_REQUEST)

        data_validation_errors = []

        if password != confirm_password:
            data_validation_errors.append("Password fields don't match")

        try:
            validator = EmailValidator()
            validator(email)
        except ValidationError as e:
            data_validation_errors.extend(e.messages)

        if len(data_validation_errors) > 0:
            print("REGISTER ERROR: validation", data_validation_errors)
            return Response(data_validation_errors, status=status.HTTP_400_BAD_REQUEST)

        existing_user = USER_MODEL.objects.filter(email=email).first()

        if existing_user is not None:
            if existing_user.is_active:
                print(f"REGISTER ERROR: user already exists -> {email}")
                return Response(f"User {email} already exists", status=status.HTTP_400_BAD_REQUEST)

            existing_user.set_password(password)
            existing_user.username = email
            existing_user.email = email
            existing_user.save()
            user = existing_user
        else:
            user = USER_MODEL.objects.create_user(
                username=email,
                email=email,
                password=password,
                is_active=False,
            )

        success = utils.send_registration_code_email(user)
        if not success:
            print(f"REGISTER ERROR: could not send registration code to {email}")
            return Response("Could not send email", status=status.HTTP_400_BAD_REQUEST)

        print(f"REGISTER OK: user created and code sent to {email}")
        return Response(
            {"detail": f"Код подтверждения отправлен на {email}"},
            status=status.HTTP_201_CREATED,
        )


class ActivateAccount(TemplateView):
    template_name = "api/account_activation.html"

    def get(self, request, *args, **kwargs):
        context = self.get_context_data(**kwargs)
        token = kwargs["token"]

        if not token or not utils.is_token_valid(token):
            context["failed_reason"] = "Token Invalid or Missing"
            return self.render_to_response(context)

        try:
            user = utils.get_user_from_token(token)
            utils.revoke_token(token)
        except USER_MODEL.DoesNotExist:
            context["failed_reason"] = "User does not exist"
            return self.render_to_response(context)

        user.is_active = True
        user.save()

        return self.render_to_response(context)


class PasswordResetRequestApi(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = PasswordResetRequestSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        user = USER_MODEL.objects.get(email__iexact=email)

        success = utils.send_password_reset_email(user)
        if not success:
            return Response({"detail": "Could not send email"}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            {"detail": f"Код для восстановления пароля отправлен на {email}."},
            status=status.HTTP_200_OK,
        )


class PasswordResetConfirmApi(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = PasswordResetConfirmSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        code = serializer.validated_data["code"]
        password = serializer.validated_data["password"]

        try:
            user, reset_code = utils.get_valid_password_reset_code(email, code)
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(password)
        user.save(update_fields=["password"])

        reset_code.is_used = True
        reset_code.save(update_fields=["is_used"])

        return Response({"detail": "Пароль успешно изменён."}, status=status.HTTP_200_OK)


class LoginDataApi(GenericAPIView):
    def get(self, request):
        data = {
            "message": "You are logged in!"
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

        friend_pairs = Friendship.objects.filter(Q(user1_id=me_id) | Q(user2_id=me_id)).values_list("user1_id", "user2_id")
        friends_ids = set()
        for u1, u2 in friend_pairs:
            friends_ids.add(u2 if u1 == me_id else u1)

        sent_pending_ids = set(
            FriendRequest.objects.filter(from_user_id=me_id, status="pending").values_list("to_user_id", flat=True)
        )
        received_pending_ids = set(
            FriendRequest.objects.filter(to_user_id=me_id, status="pending").values_list("from_user_id", flat=True)
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
            status="pending",
        )
        return Response(
            FriendRequestSerializer(fr, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class IncomingFriendRequestsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            FriendRequest.objects.filter(to_user=request.user, status="pending")
            .select_related("from_user", "to_user")
            .order_by("-created_at")
        )
        return Response(FriendRequestSerializer(qs, many=True, context={"request": request}).data)


class OutgoingFriendRequestsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            FriendRequest.objects.filter(from_user=request.user, status="pending")
            .select_related("from_user", "to_user")
            .order_by("-created_at")
        )
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

        return Response(
            FriendRequestSerializer(fr, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


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
        return Response(
            FriendRequestSerializer(fr, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class FriendsListApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        me_id = request.user.id
        pairs = Friendship.objects.filter(Q(user1_id=me_id) | Q(user2_id=me_id)).values_list("user1_id", "user2_id")

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


def is_friends(a_id: int, b_id: int) -> bool:
    u1, u2 = Friendship.make_pair(a_id, b_id)
    return Friendship.objects.filter(user1_id=u1, user2_id=u2).exists()


def require_member(group: Group, user) -> GroupMembership:
    membership = group.memberships.filter(user=user).first()
    if not membership:
        raise PermissionDenied("You are not a member of this group.")
    return membership


def require_admin(group: Group, user) -> GroupMembership:
    membership = require_member(group, user)
    if not membership.is_admin:
        raise PermissionDenied("Admin rights required.")
    return membership


def ensure_not_last_admin(group: Group, user_id: int):
    admins_count = group.memberships.filter(is_admin=True).count()
    if admins_count <= 1 and group.memberships.filter(user_id=user_id, is_admin=True).exists():
        raise ValidationError({"non_field_errors": ["Нельзя удалить/понизить последнего админа."]})


class GroupsAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            Group.objects
            .filter(memberships__user=request.user)
            .exclude(hidden_by__user=request.user)
            .distinct()
            .order_by("-created_at")
        )
        return Response(GroupListSerializer(qs, many=True, context={"request": request}).data)

    def post(self, request):
        ser = GroupCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        with transaction.atomic():
            group = Group.objects.create(
                name=ser.validated_data["name"],
                description=ser.validated_data.get("description", ""),
                created_by=request.user,
            )
            GroupMembership.objects.create(
                group=group,
                user=request.user,
                is_admin=True,
                added_by=request.user,
            )

        return Response(
            GroupDetailSerializer(group, context={"request": request}).data,
            status=201,
        )


class GroupDetailAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_member(group, request.user)
        return Response(GroupDetailSerializer(group, context={"request": request}).data)


class GroupAddMemberAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        ser = AddMemberSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user_id = ser.validated_data["user_id"]

        if user_id == request.user.id:
            raise ValidationError({"user_id": ["Нельзя добавить самого себя (ты уже в группе)."]})
        if not is_friends(request.user.id, user_id):
            raise ValidationError({"user_id": ["Можно добавлять только друзей."]})
        if group.memberships.filter(user_id=user_id).exists():
            raise ValidationError({"user_id": ["Пользователь уже в группе."]})

        GroupHidden.objects.filter(group=group, user_id=user_id).delete()
        GroupMembership.objects.create(
            group=group,
            user_id=user_id,
            is_admin=False,
            added_by=request.user,
        )
        return Response(GroupDetailSerializer(group, context={"request": request}).data, status=201)

    def get(self, request, group_id):
        group = get_object_or_404(Group, id=group_id)
        is_member = group.memberships.filter(user=request.user).exists()
        if not is_member:
            raise PermissionDenied("You are not a member of this group.")

        memberships = group.memberships.select_related("user").order_by("-is_admin", "user__username")

        data = []
        for m in memberships:
            data.append(
                {
                    "id": m.user.id,
                    "username": m.user.username,
                    "email": m.user.email,
                    "is_admin": m.is_admin,
                }
            )

        return Response(data, status=200)


class GroupRemoveMemberAPI(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, group_id: int, user_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)
        ensure_not_last_admin(group, user_id)
        deleted, _ = group.memberships.filter(user_id=user_id).delete()
        if deleted == 0:
            raise NotFound("Membership not found.")
        return Response(status=204)


class GroupLeaveAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        membership = group.memberships.filter(user=request.user).first()
        if not membership:
            raise PermissionDenied("You are not a member of this group.")

        with transaction.atomic():
            if membership.is_admin:
                admins_count = group.memberships.filter(is_admin=True).count()
                if admins_count == 1:
                    candidate = (
                        group.memberships
                        .exclude(user=request.user)
                        .order_by("?")
                        .first()
                    )
                    if candidate:
                        candidate.is_admin = True
                        candidate.save(update_fields=["is_admin"])

            membership.delete()

        return Response(status=204)


class GroupPromoteAdminAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, group_id: int, user_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        m = group.memberships.filter(user_id=user_id).first()
        if not m:
            raise NotFound("Membership not found.")

        m.is_admin = True
        m.save(update_fields=["is_admin"])
        return Response(GroupDetailSerializer(group, context={"request": request}).data)


class GroupDemoteAdminAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, group_id: int, user_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        ensure_not_last_admin(group, user_id)

        m = group.memberships.filter(user_id=user_id).first()
        if not m:
            raise NotFound("Membership not found.")

        m.is_admin = False
        m.save(update_fields=["is_admin"])
        return Response(GroupDetailSerializer(group, context={"request": request}).data)


class GroupDeleteAPI(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        group.delete()
        return Response(status=204)

class PasswordResetVerifyApi(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = PasswordResetVerifySerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        code = serializer.validated_data["code"]

        try:
            # Проверяем, что код существует/не использован/не истёк
            user, reset_code = utils.get_valid_password_reset_code(email, code)
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"detail": "Код верный."}, status=status.HTTP_200_OK)

class DailyStepsSyncApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = DailyStepsSyncSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        date = serializer.validated_data.get("date", timezone.localdate())
        steps = serializer.validated_data["steps"]

        daily_steps, _ = DailySteps.objects.update_or_create(
            user=request.user,
            date=date,
            defaults={"steps": steps},
        )

        return Response(
            DailyStepsSerializer(daily_steps).data,
            status=status.HTTP_200_OK,
        )


class MyTodayStepsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        daily_steps = DailySteps.objects.filter(
            user=request.user,
            date=today
        ).first()

        if daily_steps is None:
            return Response(
                {"date": today, "steps": 0},
                status=status.HTTP_200_OK,
            )

        return Response(
            DailyStepsSerializer(daily_steps).data,
            status=status.HTTP_200_OK,
        )


class FriendsLeaderboardApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        me = request.user

        friend_pairs = Friendship.objects.filter(
            Q(user1=me) | Q(user2=me)
        ).values_list("user1_id", "user2_id")

        friend_ids = set()
        for a, b in friend_pairs:
            friend_ids.add(b if a == me.id else a)

        user_ids = list(friend_ids | {me.id})

        users = USER_MODEL.objects.filter(id__in=user_ids).only("id", "username")
        users_map = {user.id: user for user in users}

        steps_qs = DailySteps.objects.filter(
            user_id__in=user_ids,
            date=today
        ).values("user_id", "steps")

        steps_map = {row["user_id"]: row["steps"] for row in steps_qs}

        leaderboard = []
        for user_id in user_ids:
            user = users_map.get(user_id)
            if user is None:
                continue

            leaderboard.append({
                "place": 0,
                "user_id": user.id,
                "username": user.username,
                "steps": steps_map.get(user.id, 0),
                "is_me": user.id == me.id,
            })

        leaderboard.sort(key=lambda item: (-item["steps"], item["username"].lower()))

        for index, item in enumerate(leaderboard, start=1):
            item["place"] = index

        serializer = FriendLeaderboardSerializer(leaderboard, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

class RegisterVerifyApi(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = RegisterVerifySerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        code = serializer.validated_data["code"]

        try:
            user, verification = utils.get_valid_registration_code(email, code)
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        user.is_active = True
        user.save(update_fields=["is_active"])

        verification.is_used = True
        verification.save(update_fields=["is_used"])

        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "detail": "Почта успешно подтверждена.",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "username": user.username,
                }
            },
            status=status.HTTP_200_OK,
        )

class RegisterResendApi(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = RegisterResendSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        user = USER_MODEL.objects.get(email__iexact=email)

        success = utils.send_registration_code_email(user)
        if not success:
            return Response({"detail": "Could not send email"}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            {"detail": f"Код повторно отправлен на {email}"},
            status=status.HTTP_200_OK,
        )

class SetUsernameApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SetUsernameSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)

        request.user.username = serializer.validated_data["username"]
        request.user.save(update_fields=["username"])

        return Response(
            {
                "detail": "Никнейм успешно сохранён.",
                "username": request.user.username,
            },
            status=status.HTTP_200_OK,
        )

class EmailTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer