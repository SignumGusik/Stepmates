from django.db.models import Q, Sum
from django.core.exceptions import ValidationError
from django.core.validators import EmailValidator
from django.contrib.auth import get_user_model
from django.db.utils import IntegrityError, DatabaseError
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
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import EmailTokenObtainPairSerializer, NotificationGroupSerializer, FriendPreviewSerializer
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from datetime import timedelta
from .models import UserLiveLocation
from .serializers import LiveLocationUpdateSerializer, FriendLiveLocationSerializer

from django.utils.dateparse import parse_date
from collections import defaultdict
from .models import UserTrackPoint, MatchedTrackSegment
from .serializers import (
    TrackPointsBatchSerializer,
    TrackPointReadSerializer,
    FriendTrackSerializer,
    MatchedTrackSegmentSerializer,
    FriendMatchedTrackSerializer,
)
from . import utils
from .models import FriendRequest, Friendship, Group, GroupMembership, GroupHidden, DailySteps, EmailVerificationCode, UserProfile, GroupInvite
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
    SetUsernameSerializer,
    MyProfileSerializer,
    AvatarUploadSerializer,
    AvatarResponseSerializer,
    GroupLeaderboardSerializer,
)

USER_MODEL = get_user_model()

def _avatar_url(request, user):
    profile = getattr(user, "profile", None)
    if not profile or not getattr(profile, "avatar", None):
        return None
    return request.build_absolute_uri(profile.avatar.url)

def classify_signal_quality(points):
    accuracies = [p["horizontal_accuracy"] for p in points if p.get("horizontal_accuracy") is not None]
    if not accuracies:
        return "weak"

    avg = sum(accuracies) / len(accuracies)
    if avg <= 15:
        return "good"
    if avg <= 30:
        return "weak"
    return "poor"


def smooth_points(points):
    if len(points) < 3:
        return [{"latitude": p["latitude"], "longitude": p["longitude"]} for p in points]

    result = [{
        "latitude": points[0]["latitude"],
        "longitude": points[0]["longitude"],
    }]

    for i in range(1, len(points) - 1):
        prev = points[i - 1]
        cur = points[i]
        nxt = points[i + 1]

        result.append({
            "latitude": (prev["latitude"] + cur["latitude"] + nxt["latitude"]) / 3.0,
            "longitude": (prev["longitude"] + cur["longitude"] + nxt["longitude"]) / 3.0,
        })

    result.append({
        "latitude": points[-1]["latitude"],
        "longitude": points[-1]["longitude"],
    })
    return result


def split_raw_segments(track_points):
    if not track_points:
        return []

    segments = []
    current = [track_points[0]]

    for i in range(1, len(track_points)):
        prev = track_points[i - 1]
        cur = track_points[i]

        dt = (cur.recorded_at - prev.recorded_at).total_seconds()
        if dt <= 0 or dt > 5 * 60:
            if len(current) >= 2:
                segments.append(current)
            current = [cur]
            continue

        current.append(cur)

    if len(current) >= 2:
        segments.append(current)

    return segments


def rebuild_user_matched_segments(user, day):
    raw_qs = UserTrackPoint.objects.filter(
        user=user,
        day=day
    ).order_by("recorded_at")

    MatchedTrackSegment.objects.filter(user=user, day=day).delete()

    raw_segments = split_raw_segments(list(raw_qs))

    for segment in raw_segments:
        raw_points = []
        for p in segment:
            raw_points.append({
                "latitude": p.latitude,
                "longitude": p.longitude,
                "horizontal_accuracy": p.horizontal_accuracy,
                "speed": p.speed,
                "course": p.course,
                "movement_state": p.movement_state,
                "steps_delta": p.steps_delta,
                "recorded_at": p.recorded_at.isoformat(),
            })

        signal_quality = classify_signal_quality(raw_points)

        if signal_quality == "poor":
            status_value = MatchedTrackSegment.STATUS_FALLBACK
            display_points = smooth_points(raw_points)
            confidence = "low"
        else:
            status_value = MatchedTrackSegment.STATUS_MATCHED
            display_points = smooth_points(raw_points)
            confidence = "medium" if signal_quality == "weak" else "high"

        movement_state = None
        states = [p.movement_state for p in segment if p.movement_state]
        if states:
            movement_state = max(set(states), key=states.count)

        MatchedTrackSegment.objects.create(
            user=user,
            day=day,
            started_at=segment[0].recorded_at,
            ended_at=segment[-1].recorded_at,
            raw_points=raw_points,
            display_points=display_points,
            movement_state=movement_state,
            signal_quality=signal_quality,
            matching_confidence=confidence,
            status=status_value,
        )
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
    permission_classes = [IsAuthenticated]

    def get(self, request):
        data = {
            "message": "You are logged in!",
            "user": MyProfileSerializer(request.user, context={"request": request}).data,
        }
        return JsonResponse(data, safe=False, status=status.HTTP_200_OK)


class UserSearchApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        q = (request.query_params.get("q") or "").strip()
        qs = USER_MODEL.objects.select_related("profile").all()

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

    def patch(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        name = request.data.get("name")
        status_text = request.data.get("status")
        goal_steps = request.data.get("goal_steps")

        if name is not None:
            name = str(name).strip()
            if not name:
                return Response({"name": ["Название не может быть пустым."]}, status=400)
            group.name = name

        if status_text is not None:
            group.status = str(status_text).strip()

        if goal_steps is not None:
            try:
                goal_steps = int(goal_steps)
            except (TypeError, ValueError):
                return Response({"goal_steps": ["Цель должна быть числом."]}, status=400)

            if goal_steps <= 0:
                return Response({"goal_steps": ["Цель должна быть больше 0."]}, status=400)

            group.goal_steps = goal_steps

        group.save(update_fields=["name", "status", "goal_steps"])

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
            raise ValidationError({"user_id": ["Нельзя пригласить самого себя."]})

        if not is_friends(request.user.id, user_id):
            raise ValidationError({"user_id": ["Можно приглашать только друзей."]})

        if group.memberships.filter(user_id=user_id).exists():
            raise ValidationError({"user_id": ["Пользователь уже в группе."]})

        invite, created = GroupInvite.objects.get_or_create(
            group=group,
            to_user_id=user_id,
            status=GroupInvite.Status.PENDING,
            defaults={
                "from_user": request.user,
            }
        )

        if not created:
            raise ValidationError({"user_id": ["Приглашение уже отправлено."]})

        return Response(
            GroupDetailSerializer(group, context={"request": request}).data,
            status=201
        )
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

class GroupLeaderboardAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, group_id: int):
        from django.db.models import Sum

        group = get_object_or_404(Group, id=group_id)
        require_member(group, request.user)

        today = timezone.localdate()

        period = (request.query_params.get("period") or "today").lower().strip()
        if period not in ("today", "week", "month"):
            return Response(
                {"detail": "Invalid period. Use: today | week | month"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if period == "today":
            start_date = today
        elif period == "week":
            start_date = today - timedelta(days=today.weekday())
        else:
            start_date = today.replace(day=1)

        memberships = (
            group.memberships
            .select_related("user", "user__profile")
            .all()
        )

        user_ids = [m.user_id for m in memberships]
        admins_map = {m.user_id: m.is_admin for m in memberships}
        users_map = {m.user_id: m.user for m in memberships}

        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=user_ids, date__range=(start_date, today))
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )

        steps_map = {
            row["user_id"]: row["total_steps"] or 0
            for row in steps_rows
        }

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
                "is_me": user.id == request.user.id,
                "is_admin": admins_map.get(user.id, False),
                "avatar_url": _avatar_url(request, user),
            })

        leaderboard.sort(key=lambda item: (-item["steps"], item["username"].lower()))

        for index, item in enumerate(leaderboard, start=1):
            item["place"] = index

        return Response(
            GroupLeaderboardSerializer(leaderboard, many=True).data,
            status=status.HTTP_200_OK
        )

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


class GroupAvatarAPI(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def put(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        avatar = request.FILES.get("avatar")
        if not avatar:
            return Response(
                {"detail": "avatar is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        group.avatar = avatar
        group.save(update_fields=["avatar"])

        url = request.build_absolute_uri(group.avatar.url) if group.avatar else None
        return Response({"avatar_url": url}, status=status.HTTP_200_OK)

    def delete(self, request, group_id: int):
        group = get_object_or_404(Group, id=group_id)
        require_admin(group, request.user)

        if group.avatar:
            group.avatar.delete(save=False)

        group.avatar = None
        group.save(update_fields=["avatar"])

        return Response({"detail": "avatar deleted"}, status=status.HTTP_200_OK)


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
        from django.db.models import Sum  # чтобы не править импорты наверху

        today = timezone.localdate()
        me = request.user

        period = (request.query_params.get("period") or "today").lower().strip()
        if period not in ("today", "week", "month"):
            return Response(
                {"detail": "Invalid period. Use: today | week | month"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # диапазон дат
        if period == "today":
            start_date = today
        elif period == "week":
            # понедельник текущей недели
            start_date = today - timedelta(days=today.weekday())
        else:  # month
            start_date = today.replace(day=1)

        # друзья
        friend_pairs = Friendship.objects.filter(
            Q(user1=me) | Q(user2=me)
        ).values_list("user1_id", "user2_id")

        friend_ids = set()
        for a, b in friend_pairs:
            friend_ids.add(b if a == me.id else a)

        user_ids = list(friend_ids | {me.id})

        # юзеры + профиль (для аватарки)
        users = (
            USER_MODEL.objects
            .filter(id__in=user_ids)
            .select_related("profile")
            .only("id", "username", "profile__avatar")
        )
        users_map = {u.id: u for u in users}

        # шаги: суммируем по диапазону
        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=user_ids, date__range=(start_date, today))
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )
        steps_map = {row["user_id"]: (row["total_steps"] or 0) for row in steps_rows}

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
                "avatar_url": _avatar_url(request, user),
            })

        # сортировка: больше шагов выше, при равенстве — по username
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

class MyProfileApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = USER_MODEL.objects.select_related("profile").get(pk=request.user.pk)

        current_streak_days = self._current_streak_days(user)
        total_steps = self._total_steps(user)

        friends_qs = self._friends_queryset(user)
        friends_count = friends_qs.count()
        friends_preview = friends_qs.select_related("profile")[:4]

        data = MyProfileSerializer(
            user,
            context={"request": request}
        ).data

        data["current_streak_days"] = current_streak_days
        data["total_steps"] = total_steps
        data["friends_count"] = friends_count
        data["friends_preview"] = FriendPreviewSerializer(
            friends_preview,
            many=True,
            context={"request": request}
        ).data
        data["achievements"] = self._achievements(
            streak=current_streak_days,
            total_steps=total_steps
        )

        return Response(data, status=status.HTTP_200_OK)

    def _current_streak_days(self, user):
        today = timezone.localdate()

        active_dates = set(
            DailySteps.objects
            .filter(user=user, steps__gt=0)
            .values_list("date", flat=True)
        )

        streak = 0
        current_day = today

        while current_day in active_dates:
            streak += 1
            current_day -= timedelta(days=1)

        return streak

    def _total_steps(self, user):
        return (
            DailySteps.objects
            .filter(user=user)
            .aggregate(total=Sum("steps"))
            .get("total")
            or 0
        )

    def _friends_queryset(self, user):
        pairs = Friendship.objects.filter(
            Q(user1=user) | Q(user2=user)
        ).values_list("user1_id", "user2_id")

        friend_ids = []
        for user1_id, user2_id in pairs:
            friend_ids.append(user2_id if user1_id == user.id else user1_id)

        return USER_MODEL.objects.filter(id__in=friend_ids).order_by("id")

    def _achievement_item(self, code, title, current, target):
        safe_current = max(0, current)
        progress = min(1, safe_current / target) if target > 0 else 0

        return {
            "code": code,
            "title": title,
            "current": safe_current,
            "target": target,
            "progress": progress,
            "is_finished": safe_current >= target,
        }

    def _achievements(self, streak, total_steps):
        return [
            self._achievement_item(
                code="streaks_1",
                title="Стрик 1 день",
                current=streak,
                target=1,
            ),
            self._achievement_item(
                code="streaks_7",
                title="Стрик 7 дней",
                current=streak,
                target=7,
            ),
            self._achievement_item(
                code="streaks_14",
                title="Стрик 14 дней",
                current=streak,
                target=14,
            ),
            self._achievement_item(
                code="streaks_30",
                title="Стрик месяц",
                current=streak,
                target=30,
            ),
            self._achievement_item(
                code="total_200000",
                title="200 000 шагов",
                current=total_steps,
                target=200000,
            ),
        ]

class ProfileAvatarApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = AvatarUploadSerializer

    def put(self, request):
        return self._save_avatar(request)

    def patch(self, request):
        return self._save_avatar(request)

    def _save_avatar(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.avatar = serializer.validated_data["avatar"]
        profile.save()

        return Response(
            AvatarResponseSerializer(profile, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )

    def delete(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)

        if profile.avatar:
            profile.avatar.delete(save=False)
            profile.avatar = None
            profile.avatar_updated_at = None
            profile.save(update_fields=["avatar", "avatar_updated_at", "updated_at"])

        return Response(status=status.HTTP_204_NO_CONTENT)


class SetUsernameApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SetUsernameSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)

        request.user.username = serializer.validated_data["username"]
        request.user.save(update_fields=["username"])

        request.user = USER_MODEL.objects.select_related("profile").get(pk=request.user.pk)
        return Response(
            {
                "detail": "Никнейм успешно сохранён.",
                "username": request.user.username,
                "avatar_url": MyProfileSerializer(request.user, context={"request": request}).data.get("avatar_url"),
            },
            status=status.HTTP_200_OK,
        )

class EmailTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer


class MyLiveLocationApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = LiveLocationUpdateSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        obj, _ = UserLiveLocation.objects.update_or_create(
            user=request.user,
            defaults=serializer.validated_data,
        )

        return Response(
            {
                "detail": "Live location updated",
                "updated_at": obj.updated_at,
            },
            status=status.HTTP_200_OK,
        )


class FriendsLiveLocationApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        me_id = request.user.id

        friend_pairs = Friendship.objects.filter(
            Q(user1_id=me_id) | Q(user2_id=me_id)
        ).values_list("user1_id", "user2_id")

        friend_ids = set()
        for u1, u2 in friend_pairs:
            friend_ids.add(u2 if u1 == me_id else u1)

        fresh_after = timezone.now() - timedelta(minutes=5)

        qs = (
            USER_MODEL.objects
            .filter(id__in=friend_ids)
            .select_related("profile", "live_location")
        )

        result = []
        for user in qs:
            live = getattr(user, "live_location", None)
            if not live:
                continue
            if not live.is_sharing:
                continue
            if live.updated_at < fresh_after:
                continue

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "latitude": live.latitude,
                "longitude": live.longitude,
                "updated_at": live.updated_at,
                "is_me": False,
            })

        return Response(
            FriendLiveLocationSerializer(result, many=True).data,
            status=status.HTTP_200_OK,
        )

class UserCardApi(APIView):
    """
    Карточка пользователя для SelectedUserViewController.

    GET /api/users/<id>/card/

    Возвращает:
    - id, username, avatar_url
    - is_friend, request_sent, request_received
    - friends_count, mutual_friends_count
    - friends_preview_avatar_urls (max 4)
    - mutual_preview_avatar_urls (max 4)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id: int):
        me = request.user

        try:
            target = USER_MODEL.objects.select_related("profile").get(pk=user_id)
        except USER_MODEL.DoesNotExist:
            return Response({"detail": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        my_pairs = Friendship.objects.filter(Q(user1=me) | Q(user2=me)).values_list("user1_id", "user2_id")
        my_friend_ids = set()
        for a, b in my_pairs:
            my_friend_ids.add(b if a == me.id else a)
        target_pairs = Friendship.objects.filter(Q(user1=target) | Q(user2=target)).values_list("user1_id", "user2_id")
        target_friend_ids = set()
        for a, b in target_pairs:
            target_friend_ids.add(b if a == target.id else a)

        friends_count = len(target_friend_ids)

        mutual_ids = list(my_friend_ids & target_friend_ids)
        mutual_friends_count = len(mutual_ids)
        a_id, b_id = Friendship.make_pair(me.id, target.id)
        is_friend = Friendship.objects.filter(user1_id=a_id, user2_id=b_id).exists()

        request_sent = FriendRequest.objects.filter(
            from_user=me, to_user=target, status=FriendRequest.Status.PENDING
        ).exists()

        request_received = FriendRequest.objects.filter(
            from_user=target, to_user=me, status=FriendRequest.Status.PENDING
        ).exists()

        friends_preview_avatar_urls = []
        if target_friend_ids:
            qs = USER_MODEL.objects.filter(id__in=list(target_friend_ids)).select_related("profile").order_by("?")[:4]
            for u in qs:
                friends_preview_avatar_urls.append(utils._avatar_url(request, u))

        mutual_preview_avatar_urls = []
        if mutual_ids:
            qs = USER_MODEL.objects.filter(id__in=mutual_ids).select_related("profile").order_by("?")[:4]
            for u in qs:
                mutual_preview_avatar_urls.append(utils._avatar_url(request, u))

        payload = {
            "id": target.id,
            "username": target.username,
            "avatar_url": utils._avatar_url(request, target),

            "is_friend": is_friend,
            "request_sent": request_sent,
            "request_received": request_received,

            "friends_count": friends_count,
            "mutual_friends_count": mutual_friends_count,

            "friends_preview_avatar_urls": friends_preview_avatar_urls,
            "mutual_preview_avatar_urls": mutual_preview_avatar_urls,
        }

        return Response(payload, status=status.HTTP_200_OK)



class CancelOutgoingFriendRequestApi(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, user_id: int):
        if user_id == request.user.id:
            return Response(
                {"detail": "Нельзя отменить запрос самому себе."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        fr = FriendRequest.objects.filter(
            from_user=request.user,
            to_user_id=user_id,
            status="pending",
        ).first()

        if fr is None:
            return Response(
                {"detail": "Исходящий запрос не найден."},
                status=status.HTTP_404_NOT_FOUND,
            )

        fr.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyTrackPointsApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = TrackPointsBatchSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        created = 0
        for item in serializer.validated_data["points"]:
            recorded_at = item["recorded_at"]

            UserTrackPoint.objects.create(
                user=request.user,
                latitude=item["latitude"],
                longitude=item["longitude"],
                horizontal_accuracy=item.get("horizontal_accuracy"),
                speed=item.get("speed"),
                course=item.get("course"),
                movement_state=item.get("movement_state"),
                steps_delta=item.get("steps_delta"),
                recorded_at=recorded_at,
                day=timezone.localtime(recorded_at).date(),
            )
            created += 1

        rebuild_user_matched_segments(request.user, timezone.localdate())

        return Response({"created": created}, status=status.HTTP_200_OK)


class MyTrackApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        day_param = request.query_params.get("day", "today")

        if day_param == "today":
            day = timezone.localdate()
        else:
            parsed = parse_date(day_param)
            if not parsed:
                return Response(
                    {"detail": "Некорректный day. Используй YYYY-MM-DD или today."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            day = parsed

        qs = UserTrackPoint.objects.filter(
            user=request.user,
            day=day,
        ).order_by("recorded_at")

        data = [
            {
                "latitude": p.latitude,
                "longitude": p.longitude,
                "horizontal_accuracy": p.horizontal_accuracy,
                "speed": p.speed,
                "course": p.course,
                "movement_state": p.movement_state,
                "steps_delta": p.steps_delta,
                "recorded_at": p.recorded_at,
            }
            for p in qs
        ]

        return Response(TrackPointReadSerializer(data, many=True).data, status=status.HTTP_200_OK)


class FriendsTracksApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        me_id = request.user.id
        day_param = request.query_params.get("day", "today")

        if day_param == "today":
            day = timezone.localdate()
        else:
            parsed = parse_date(day_param)
            if not parsed:
                return Response(
                    {"detail": "Некорректный day. Используй YYYY-MM-DD или today."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            day = parsed

        friend_pairs = Friendship.objects.filter(
            Q(user1_id=me_id) | Q(user2_id=me_id)
        ).values_list("user1_id", "user2_id")

        friend_ids = set()
        for u1, u2 in friend_pairs:
            friend_ids.add(u2 if u1 == me_id else u1)

        users = {
            user.id: user
            for user in USER_MODEL.objects.filter(id__in=friend_ids).select_related("profile")
        }

        points_qs = UserTrackPoint.objects.filter(
            user_id__in=friend_ids,
            day=day
        ).order_by("user_id", "recorded_at")

        grouped = defaultdict(list)
        for point in points_qs:
            grouped[point.user_id].append({
                "latitude": point.latitude,
                "longitude": point.longitude,
                "horizontal_accuracy": point.horizontal_accuracy,
                "speed": point.speed,
                "course": point.course,
                "movement_state": point.movement_state,
                "steps_delta": point.steps_delta,
                "recorded_at": point.recorded_at,
            })

        result = []
        for user_id, points in grouped.items():
            user = users.get(user_id)
            if not user or len(points) < 2:
                continue

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "points": points,
            })

        return Response(
            FriendTrackSerializer(result, many=True).data,
            status=status.HTTP_200_OK,
        )


class MyMatchedTrackApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        day_param = request.query_params.get("day", "today")

        if day_param == "today":
            day = timezone.localdate()
        else:
            parsed = parse_date(day_param)
            if not parsed:
                return Response({"detail": "Некорректный day"}, status=status.HTTP_400_BAD_REQUEST)
            day = parsed

        qs = MatchedTrackSegment.objects.filter(
            user=request.user,
            day=day
        ).order_by("started_at")

        data = [
            {
                "started_at": s.started_at,
                "ended_at": s.ended_at,
                "status": s.status,
                "signal_quality": s.signal_quality,
                "matching_confidence": s.matching_confidence,
                "display_points": s.display_points,
            }
            for s in qs
        ]

        return Response(data, status=status.HTTP_200_OK)


class FriendsMatchedTracksApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        day_param = request.query_params.get("day", "today")

        if day_param == "today":
            day = timezone.localdate()
        else:
            parsed = parse_date(day_param)
            if not parsed:
                return Response({"detail": "Некорректный day"}, status=status.HTTP_400_BAD_REQUEST)
            day = parsed

        my_id = request.user.id

        friendship_qs = Friendship.objects.filter(
            Q(user1_id=my_id) | Q(user2_id=my_id)
        )

        friend_ids = set()
        for item in friendship_qs:
            friend_ids.add(item.user2_id if item.user1_id == my_id else item.user1_id)

        users = {
            u.id: u
            for u in USER_MODEL.objects.filter(id__in=friend_ids).select_related("profile")
        }

        grouped = defaultdict(list)
        segments = MatchedTrackSegment.objects.filter(
            user_id__in=friend_ids,
            day=day
        ).order_by("user_id", "started_at")

        for s in segments:
            grouped[s.user_id].append({
                "started_at": s.started_at,
                "ended_at": s.ended_at,
                "status": s.status,
                "signal_quality": s.signal_quality,
                "matching_confidence": s.matching_confidence,
                "display_points": s.display_points,
            })

        result = []
        for user_id, user_segments in grouped.items():
            user = users.get(user_id)
            if not user:
                continue

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "segments": user_segments,
            })

        return Response(result, status=status.HTTP_200_OK)

class NotificationsAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        result = []

        incoming_friend_requests = (
            FriendRequest.objects
            .filter(to_user=request.user, status=FriendRequest.Status.PENDING)
            .select_related("from_user", "from_user__profile")
            .order_by("-created_at")
        )

        for req in incoming_friend_requests:
            result.append({
                "id": req.id,
                "type": "friend_request",
                "created_at": req.created_at,
                "from_user": UserShortSerializer(req.from_user, context={"request": request}).data,
                "to_user": UserShortSerializer(req.to_user, context={"request": request}).data,
                "group": None,
                "status": req.status,
            })

        accepted_friend_requests = (
            FriendRequest.objects
            .filter(
                from_user=request.user,
                status=FriendRequest.Status.ACCEPTED,
                seen_by_from_user=False
            )
            .select_related("from_user", "to_user", "to_user__profile")
            .order_by("-created_at")
        )

        for req in accepted_friend_requests:
            result.append({
                "id": req.id,
                "type": "friend_request_accepted",
                "created_at": req.created_at,
                "from_user": UserShortSerializer(req.to_user, context={"request": request}).data,
                "to_user": UserShortSerializer(req.from_user, context={"request": request}).data,
                "group": None,
                "status": req.status,
            })

        group_invites = (
            GroupInvite.objects
            .filter(to_user=request.user, status=GroupInvite.Status.PENDING)
            .select_related(
                "from_user",
                "from_user__profile",
                "to_user",
                "group",
            )
            .order_by("-created_at")
        )

        for invite in group_invites:
            result.append({
                "id": invite.id,
                "type": "group_invite",
                "created_at": invite.created_at,
                "from_user": UserShortSerializer(invite.from_user, context={"request": request}).data,
                "to_user": UserShortSerializer(invite.to_user, context={"request": request}).data,
                "group": NotificationGroupSerializer(invite.group, context={"request": request}).data,
                "status": invite.status,
            })

        result.sort(key=lambda item: item["created_at"], reverse=True)

        return Response(result, status=200)

class AcceptGroupInviteAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, invite_id: int):
        invite = get_object_or_404(
            GroupInvite.objects.select_related("group", "from_user", "to_user"),
            id=invite_id,
        )

        if invite.to_user_id != request.user.id:
            return Response({"detail": "Нельзя принять чужое приглашение."}, status=403)

        if invite.status != GroupInvite.Status.PENDING:
            return Response({"detail": "Приглашение уже обработано."}, status=400)

        with transaction.atomic():
            GroupHidden.objects.filter(group=invite.group, user=request.user).delete()

            GroupMembership.objects.get_or_create(
                group=invite.group,
                user=request.user,
                defaults={
                    "is_admin": False,
                    "added_by": invite.from_user,
                }
            )

            invite.status = GroupInvite.Status.ACCEPTED
            invite.save(update_fields=["status"])

        return Response({"detail": "Приглашение принято."}, status=200)


class RejectGroupInviteAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, invite_id: int):
        invite = get_object_or_404(GroupInvite, id=invite_id)

        if invite.to_user_id != request.user.id:
            return Response({"detail": "Нельзя отклонить чужое приглашение."}, status=403)

        if invite.status != GroupInvite.Status.PENDING:
            return Response({"detail": "Приглашение уже обработано."}, status=400)

        invite.status = GroupInvite.Status.REJECTED
        invite.save(update_fields=["status"])

        return Response({"detail": "Приглашение отклонено."}, status=200)


class DismissFriendAcceptedNotificationAPI(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, request_id: int):
        friend_request = get_object_or_404(
            FriendRequest,
            id=request_id,
            from_user=request.user,
            status=FriendRequest.Status.ACCEPTED
        )

        friend_request.seen_by_from_user = True
        friend_request.save(update_fields=["seen_by_from_user"])

        return Response({"detail": "Уведомление скрыто."}, status=200)


class MapGroupsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        groups = (
            Group.objects
            .filter(memberships__user=request.user)
            .prefetch_related("memberships")
            .order_by("name")
        )

        return Response(
            GroupListSerializer(groups, many=True, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class GroupLiveLocationApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, group_id: int):
        group = Group.objects.filter(
            id=group_id,
            memberships__user=request.user,
        ).first()

        if not group:
            return Response({"detail": "Группа не найдена."}, status=status.HTTP_404_NOT_FOUND)

        member_ids = set(
            group.memberships.values_list("user_id", flat=True)
        )

        now = timezone.now()
        freshness_limit = now - timedelta(minutes=30)

        locations = (
            UserLiveLocation.objects
            .filter(
                user_id__in=member_ids,
                is_sharing=True,
                updated_at__gte=freshness_limit,
            )
            .select_related("user", "user__profile")
        )

        result = []
        for loc in locations:
            user = loc.user
            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "updated_at": loc.updated_at,
                "is_me": user.id == request.user.id,
            })

        return Response(
            FriendLiveLocationSerializer(result, many=True).data,
            status=status.HTTP_200_OK,
        )


class GroupMatchedTracksApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, group_id: int):
        group = Group.objects.filter(
            id=group_id,
            memberships__user=request.user,
        ).first()

        if not group:
            return Response({"detail": "Группа не найдена."}, status=status.HTTP_404_NOT_FOUND)

        day_param = request.query_params.get("day", "today")

        if day_param == "today":
            day = timezone.localdate()
        else:
            parsed = parse_date(day_param)
            if not parsed:
                return Response({"detail": "Некорректный day"}, status=status.HTTP_400_BAD_REQUEST)
            day = parsed

        member_ids = set(
            group.memberships
            .exclude(user=request.user)
            .values_list("user_id", flat=True)
        )

        users = {
            u.id: u
            for u in USER_MODEL.objects
            .filter(id__in=member_ids)
            .select_related("profile")
        }

        grouped = defaultdict(list)

        segments = (
            MatchedTrackSegment.objects
            .filter(user_id__in=member_ids, day=day)
            .order_by("user_id", "started_at")
        )

        for s in segments:
            grouped[s.user_id].append({
                "started_at": s.started_at,
                "ended_at": s.ended_at,
                "status": s.status,
                "signal_quality": s.signal_quality,
                "matching_confidence": s.matching_confidence,
                "display_points": s.display_points,
            })

        result = []
        for user_id, user_segments in grouped.items():
            user = users.get(user_id)
            if not user:
                continue

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "segments": user_segments,
            })

        return Response(
            FriendMatchedTrackSerializer(result, many=True).data,
            status=status.HTTP_200_OK,
        )

class MapFriendsRankingApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.localdate()
        me_id = request.user.id

        friend_pairs = Friendship.objects.filter(
            Q(user1_id=me_id) | Q(user2_id=me_id)
        ).values_list("user1_id", "user2_id")

        ids = {me_id}
        for u1, u2 in friend_pairs:
            ids.add(u2 if u1 == me_id else u1)

        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=ids, date=today)
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )

        steps_map = {
            row["user_id"]: row["total_steps"] or 0
            for row in steps_rows
        }

        sorted_ids = sorted(ids, key=lambda uid: (-steps_map.get(uid, 0), uid))

        return Response({
            "my_place": sorted_ids.index(me_id) + 1 if me_id in sorted_ids else None,
            "total": len(sorted_ids),
            "steps": steps_map.get(me_id, 0),
        })


class MapGroupRankingApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, group_id: int):
        group = Group.objects.filter(
            id=group_id,
            memberships__user=request.user,
        ).first()

        if not group:
            return Response({"detail": "Группа не найдена."}, status=status.HTTP_404_NOT_FOUND)

        today = timezone.localdate()
        me_id = request.user.id

        ids = set(group.memberships.values_list("user_id", flat=True))

        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=ids, date=today)
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )

        steps_map = {
            row["user_id"]: row["total_steps"] or 0
            for row in steps_rows
        }

        sorted_ids = sorted(ids, key=lambda uid: (-steps_map.get(uid, 0), uid))

        return Response({
            "my_place": sorted_ids.index(me_id) + 1 if me_id in sorted_ids else None,
            "total": len(sorted_ids),
            "steps": steps_map.get(me_id, 0),
        })