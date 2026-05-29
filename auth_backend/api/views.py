from django.db.models import Q, Sum, Max
from django.core.cache import cache
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
import math
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
    DailyGoalSerializer,
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

def _requested_steps_date(request):
    date_param = request.query_params.get("date")
    if not date_param:
        return timezone.localdate(), None

    requested_date = parse_date(date_param)
    if requested_date is None:
        return None, Response(
            {"detail": "Некорректная дата. Используйте формат YYYY-MM-DD."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if requested_date > timezone.localdate() + timedelta(days=1):
        return None, Response(
            {"detail": "Нельзя запрашивать шаги из будущего."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    return requested_date, None

MOVEMENT_KIND_ALIASES = {
    "walking": "walking",
    "running": "walking",
    "stationary": "stationary",
    "automotive": "transport",
    "cycling": "transport",
    "transport": "transport",
    "signal_lost": "signal_lost",
    "unknown": "unknown",
}

BREAK_REASONS = {
    "lost_signal",
    "vehicle_jump",
    "poor_accuracy",
    "app_background",
    "stale_location",
}

PRECISE_TIME_GAP_SECONDS = 35
MAX_JUMP_DISTANCE_METERS = 120
MAX_JUMP_SPEED_METERS_PER_SECOND = 4.5
TRACK_POINTS_BULK_CREATE_BATCH_SIZE = 250
MATCHED_SEGMENTS_BULK_CREATE_BATCH_SIZE = 100
MATCHED_REBUILD_THROTTLE_SECONDS = 25


def blank_to_none(value):
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def clamp_confidence_score(value):
    if value is None:
        return None
    try:
        return max(0, min(100, int(value)))
    except (TypeError, ValueError):
        return None


def normalize_movement_kind(value):
    value = blank_to_none(value)
    if value is None:
        return None
    return MOVEMENT_KIND_ALIASES.get(value, "unknown")


def normalize_break_reason(value):
    value = blank_to_none(value)
    if value in BREAK_REASONS:
        return value
    return None


def dominant_value(values):
    values = [value for value in values if value]
    if not values:
        return None
    return max(set(values), key=values.count)


def distance_meters(a, b):
    lat1 = math.radians(a["latitude"])
    lat2 = math.radians(b["latitude"])
    dlat = lat2 - lat1
    dlon = math.radians(b["longitude"] - a["longitude"])
    sin_dlat = math.sin(dlat / 2)
    sin_dlon = math.sin(dlon / 2)
    value = sin_dlat * sin_dlat + math.cos(lat1) * math.cos(lat2) * sin_dlon * sin_dlon
    value = max(0, min(1, value))
    return 6371000 * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value))


def movement_kind_for_point(point):
    explicit = normalize_movement_kind(point.get("movement_kind"))
    if explicit:
        return explicit

    state = normalize_movement_kind(point.get("movement_state"))
    if state:
        return state

    speed = point.get("speed")
    if speed is not None and speed > 7:
        return "transport"

    if (point.get("steps_delta") or 0) > 0:
        return "walking"

    return "unknown"


def confidence_score_for_point(point, previous=None):
    explicit = clamp_confidence_score(point.get("confidence_score"))
    if explicit is not None:
        return explicit

    score = 100
    accuracy = point.get("horizontal_accuracy")

    if accuracy is None:
        score -= 30
    elif accuracy <= 12:
        score -= 0
    elif accuracy <= 20:
        score -= 8
    elif accuracy <= 45:
        score -= 22
    elif accuracy <= 100:
        score -= 48
    else:
        score -= 68

    speed = point.get("speed")
    if speed is not None:
        if speed > 13:
            score -= 18
        elif speed > 7:
            score -= 8

    if previous:
        dt = (point["recorded_at_dt"] - previous["recorded_at_dt"]).total_seconds()
        if dt > PRECISE_TIME_GAP_SECONDS:
            score -= 24
        if dt > 0:
            distance = distance_meters(previous, point)
            derived_speed = distance / dt
            if distance > MAX_JUMP_DISTANCE_METERS and derived_speed > MAX_JUMP_SPEED_METERS_PER_SECOND:
                score -= 28

    movement_kind = movement_kind_for_point(point)
    if movement_kind == "walking" and (point.get("steps_delta") or 0) > 0:
        score += 5
    if movement_kind == "stationary" and speed is not None and speed > 2:
        score -= 14

    return max(0, min(100, score))


def break_reason_for_point(point, previous=None):
    explicit = normalize_break_reason(point.get("break_reason"))
    if explicit:
        return explicit

    movement_kind = movement_kind_for_point(point)
    if movement_kind == "transport":
        return "vehicle_jump"

    accuracy = point.get("horizontal_accuracy")
    if accuracy is not None and accuracy > 45:
        return "poor_accuracy"

    if previous:
        dt = (point["recorded_at_dt"] - previous["recorded_at_dt"]).total_seconds()
        if dt > PRECISE_TIME_GAP_SECONDS:
            return "app_background"

        if dt > 0:
            distance = distance_meters(previous, point)
            derived_speed = distance / dt
            if distance > MAX_JUMP_DISTANCE_METERS and derived_speed > MAX_JUMP_SPEED_METERS_PER_SECOND:
                return "vehicle_jump"

    if confidence_score_for_point(point, previous) < 28:
        return "lost_signal"

    return None


def signal_quality_from_score(score):
    if score >= 78:
        return "good"
    if score >= 42:
        return "weak"
    return "poor"


def matching_confidence_from_score(score):
    if score >= 78:
        return "high"
    if score >= 42:
        return "medium"
    return "low"


def classify_signal_quality(points):
    if not points:
        return "weak"
    avg = sum(point["confidence_score"] for point in points) / len(points)
    return signal_quality_from_score(avg)


def display_point_from(source, latitude=None, longitude=None):
    result = {
        "latitude": latitude if latitude is not None else source["latitude"],
        "longitude": longitude if longitude is not None else source["longitude"],
    }
    for key in ("confidence_score", "movement_kind", "break_reason"):
        if source.get(key) is not None:
            result[key] = source[key]
    return result


def smooth_points(points):
    if len(points) < 3:
        return [display_point_from(point) for point in points]

    result = [display_point_from(points[0])]

    for i in range(1, len(points) - 1):
        prev = points[i - 1]
        cur = points[i]
        nxt = points[i + 1]

        can_smooth = (
            cur.get("break_reason") is None
            and cur.get("movement_kind") in ("walking", "unknown")
            and cur.get("confidence_score", 0) >= 42
        )

        if can_smooth:
            result.append(display_point_from(
                cur,
                latitude=(prev["latitude"] + cur["latitude"] + nxt["latitude"]) / 3.0,
                longitude=(prev["longitude"] + cur["longitude"] + nxt["longitude"]) / 3.0,
            ))
        else:
            result.append(display_point_from(cur))

    result.append(display_point_from(points[-1]))
    return result


def raw_point_dict(point, previous=None):
    result = {
        "latitude": point.latitude,
        "longitude": point.longitude,
        "horizontal_accuracy": point.horizontal_accuracy,
        "speed": point.speed,
        "course": point.course,
        "movement_state": point.movement_state,
        "movement_kind": point.movement_kind,
        "break_reason": point.break_reason,
        "confidence_score": point.confidence_score,
        "steps_delta": point.steps_delta,
        "recorded_at": point.recorded_at.isoformat(),
        "recorded_at_dt": point.recorded_at,
    }
    result["movement_kind"] = movement_kind_for_point(result)
    result["confidence_score"] = confidence_score_for_point(result, previous)
    result["break_reason"] = break_reason_for_point(result, previous)
    return result


def public_track_point_dict(point):
    return {
        "latitude": point.latitude,
        "longitude": point.longitude,
        "horizontal_accuracy": point.horizontal_accuracy,
        "speed": point.speed,
        "course": point.course,
        "movement_state": point.movement_state,
        "movement_kind": point.movement_kind,
        "break_reason": point.break_reason,
        "confidence_score": point.confidence_score,
        "steps_delta": point.steps_delta,
        "recorded_at": point.recorded_at,
    }


def should_start_new_segment(prev_data, cur_data):
    dt = (cur_data["recorded_at_dt"] - prev_data["recorded_at_dt"]).total_seconds()
    if dt <= 0 or dt > PRECISE_TIME_GAP_SECONDS:
        return True

    if cur_data["movement_kind"] != prev_data["movement_kind"]:
        return True

    if cur_data.get("break_reason") != prev_data.get("break_reason"):
        return True

    return False


def split_raw_segments(track_points):
    segments = []
    current = []
    previous = None

    for point in track_points:
        current_point = raw_point_dict(point, previous)

        if previous is not None and should_start_new_segment(previous, current_point):
            if len(current) >= 2:
                segments.append(current)
            current = [current_point]
            previous = current_point
            continue

        current.append(current_point)
        previous = current_point

    if len(current) >= 2:
        segments.append(current)

    return segments


def matched_segment_dict(segment):
    return {
        "started_at": segment.started_at,
        "ended_at": segment.ended_at,
        "status": segment.status,
        "signal_quality": segment.signal_quality,
        "matching_confidence": segment.matching_confidence,
        "confidence_score": segment.confidence_score,
        "movement_state": segment.movement_state,
        "movement_kind": segment.movement_kind,
        "break_reason": segment.break_reason,
        "display_points": segment.display_points,
    }


def rebuild_user_matched_segments(user, day):
    raw_qs = (
        UserTrackPoint.objects
        .filter(user=user, day=day)
        .only(
            "latitude",
            "longitude",
            "horizontal_accuracy",
            "speed",
            "course",
            "movement_state",
            "movement_kind",
            "break_reason",
            "confidence_score",
            "steps_delta",
            "recorded_at",
        )
        .order_by("recorded_at")
        .iterator(chunk_size=500)
    )

    matched_segments = []
    raw_segments = split_raw_segments(raw_qs)
    for segment in raw_segments:
        raw_points = [
            {
                key: value
                for key, value in point.items()
                if key != "recorded_at_dt"
            }
            for point in segment
        ]

        signal_quality = classify_signal_quality(raw_points)
        confidence_score = int(sum(p["confidence_score"] for p in raw_points) / len(raw_points))
        movement_state = dominant_value([p.get("movement_state") for p in raw_points])
        movement_kind = dominant_value([p.get("movement_kind") for p in raw_points]) or "unknown"
        break_reason = dominant_value([p.get("break_reason") for p in raw_points])

        if movement_kind == "transport":
            break_reason = break_reason or "vehicle_jump"
        elif movement_kind == "signal_lost":
            break_reason = break_reason or "lost_signal"
        elif signal_quality == "poor":
            break_reason = break_reason or "poor_accuracy"

        is_drawable_walk = movement_kind in ("walking", "unknown") and not break_reason and signal_quality != "poor"
        status_value = MatchedTrackSegment.STATUS_MATCHED if is_drawable_walk else MatchedTrackSegment.STATUS_FALLBACK

        matched_segments.append(MatchedTrackSegment(
            user_id=user.id,
            day=day,
            started_at=segment[0]["recorded_at_dt"],
            ended_at=segment[-1]["recorded_at_dt"],
            raw_points=raw_points,
            display_points=smooth_points(raw_points),
            movement_state=movement_state,
            movement_kind=movement_kind,
            break_reason=break_reason,
            confidence_score=confidence_score,
            signal_quality=signal_quality,
            matching_confidence=matching_confidence_from_score(confidence_score),
            status=status_value,
        ))

    with transaction.atomic():
        MatchedTrackSegment.objects.filter(user=user, day=day).delete()
        if matched_segments:
            MatchedTrackSegment.objects.bulk_create(
                matched_segments,
                batch_size=MATCHED_SEGMENTS_BULK_CREATE_BATCH_SIZE,
            )

    return len(matched_segments)


def matched_rebuild_cache_key(user_id, day):
    return f"matched-track-rebuild:{user_id}:{day.isoformat()}"


def rebuild_user_matched_segments_throttled(user, day, force=False):
    cache_key = matched_rebuild_cache_key(user.id, day)

    if not force and not cache.add(cache_key, "1", timeout=MATCHED_REBUILD_THROTTLE_SECONDS):
        return False

    try:
        rebuild_user_matched_segments(user, day)
        cache.set(cache_key, "1", timeout=MATCHED_REBUILD_THROTTLE_SECONDS)
        return True
    except Exception:
        cache.delete(cache_key)
        raise


def matched_segments_are_stale(user, day):
    latest_raw_at = (
        UserTrackPoint.objects
        .filter(user=user, day=day)
        .aggregate(value=Max("recorded_at"))
        .get("value")
    )

    if latest_raw_at is None:
        return False

    latest_matched_at = (
        MatchedTrackSegment.objects
        .filter(user=user, day=day)
        .aggregate(value=Max("ended_at"))
        .get("value")
    )

    if latest_matched_at is None:
        return True

    return latest_matched_at < latest_raw_at


class RegisterAppUser(GenericAPIView):
    permission_classes = [AllowAny]

    def post(self, request):
        import traceback
        from django.conf import settings

        try:
            print("REGISTER DEBUG START")
            print("DISABLE_EMAIL =", getattr(settings, "DISABLE_EMAIL", None))
            print("REQUEST DATA =", request.data)

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
            print("EXISTING USER =", existing_user)

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

            print("USER CREATED/UPDATED =", user.id, user.email)

            success = utils.send_registration_code_email(user)
            print("EMAIL FUNCTION SUCCESS =", success)

            if not success:
                print(f"REGISTER ERROR: could not send registration code to {email}")
                return Response("Could not send email", status=status.HTTP_400_BAD_REQUEST)

            print(f"REGISTER OK: user created and code sent to {email}")
            return Response(
                {"detail": f"Код подтверждения отправлен на {email}"},
                status=status.HTTP_201_CREATED,
            )

        except Exception as e:
            print("REGISTER EXCEPTION:", repr(e))
            traceback.print_exc()
            return Response(
                {
                    "error": str(e),
                    "type": type(e).__name__,
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
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


def build_group_list_stats(groups, user_id: int, today=None):
    today = today or timezone.localdate()
    member_ids_by_group = {}
    all_member_ids = set()
    stats = {}

    for group in groups:
        memberships = list(group.memberships.all())
        member_ids = [membership.user_id for membership in memberships]
        member_ids_by_group[group.id] = member_ids
        all_member_ids.update(member_ids)

        stats[group.id] = {
            "members_count": len(member_ids),
            "is_admin": any(
                membership.user_id == user_id and membership.is_admin
                for membership in memberships
            ),
            "my_place": None,
        }

    steps_rows = (
        DailySteps.objects
        .filter(user_id__in=all_member_ids, date=today)
        .values("user_id")
        .annotate(total_steps=Sum("steps"))
    )
    steps_map = {
        row["user_id"]: row["total_steps"] or 0
        for row in steps_rows
    }

    for group_id, member_ids in member_ids_by_group.items():
        sorted_ids = sorted(
            member_ids,
            key=lambda member_id: (-steps_map.get(member_id, 0), member_id)
        )
        if user_id in sorted_ids:
            stats[group_id]["my_place"] = sorted_ids.index(user_id) + 1

    return stats


class GroupsAPI(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            Group.objects
            .filter(memberships__user=request.user)
            .exclude(hidden_by__user=request.user)
            .distinct()
            .prefetch_related("memberships")
            .order_by("-created_at")
        )

        if str(request.query_params.get("compact", "")).lower() in ("1", "true", "yes"):
            return Response(list(qs.values("id")))

        today, error_response = _requested_steps_date(request)
        if error_response is not None:
            return error_response

        groups = list(qs)
        context = {
            "request": request,
            "group_list_stats": build_group_list_stats(groups, request.user.id, today=today),
        }
        return Response(GroupListSerializer(groups, many=True, context=context).data)

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
            return Response(
                {
                    "detail": "Вы уже отправляли пользователю приглашение.",
                    "code": "group_invite_already_sent",
                    "user_id": ["Приглашение уже отправлено."],
                },
                status=400,
            )

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

        today, error_response = _requested_steps_date(request)
        if error_response is not None:
            return error_response

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
        profile, _ = UserProfile.objects.get_or_create(user=request.user)

        server_today = timezone.localdate()
        daily_steps, created = DailySteps.objects.get_or_create(
            user=request.user,
            date=date,
            defaults={
                "steps": steps,
                "goal_steps": profile.daily_goal_steps,
            },
        )

        if not created:
            update_fields = []

            # Never let a stale/partial mobile sync wipe a completed day.
            # The app can read 0 or a lower value during permission/provider
            # switches, especially around midnight, so the server keeps the
            # best value received for that date.
            if steps > daily_steps.steps:
                daily_steps.steps = steps
                update_fields.append("steps")

            if date >= server_today and daily_steps.goal_steps != profile.daily_goal_steps:
                daily_steps.goal_steps = profile.daily_goal_steps
                update_fields.append("goal_steps")

            if update_fields:
                update_fields.append("updated_at")
                daily_steps.save(update_fields=update_fields)

        return Response(
            DailyStepsSerializer(daily_steps).data,
            status=status.HTTP_200_OK,
        )


class DailyGoalApi(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = DailyGoalSerializer

    def patch(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        goal_steps = serializer.validated_data["daily_goal_steps"]
        date = serializer.validated_data.get("date", timezone.localdate())
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.daily_goal_steps = goal_steps
        profile.save(update_fields=["daily_goal_steps", "updated_at"])

        daily_steps, _ = DailySteps.objects.get_or_create(
            user=request.user,
            date=date,
            defaults={
                "steps": 0,
                "goal_steps": goal_steps,
            },
        )

        if daily_steps.goal_steps != goal_steps:
            daily_steps.goal_steps = goal_steps
            daily_steps.save(update_fields=["goal_steps", "updated_at"])

        return Response(
            {
                "daily_goal_steps": goal_steps,
                "date": date,
                "today_steps": daily_steps.steps,
                "is_goal_completed": daily_steps.steps >= goal_steps,
            },
            status=status.HTTP_200_OK,
        )


class MyTodayStepsApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        requested_date = timezone.localdate()
        date_param = request.query_params.get("date")

        if date_param:
            requested_date = parse_date(date_param)
            if requested_date is None:
                return Response(
                    {"detail": "Некорректная дата. Используйте формат YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if requested_date > timezone.localdate() + timedelta(days=1):
                return Response(
                    {"detail": "Нельзя запрашивать шаги из будущего."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        daily_steps = DailySteps.objects.filter(
            user=request.user,
            date=requested_date
        ).first()

        if daily_steps is None:
            return Response(
                {
                    "date": requested_date,
                    "steps": 0,
                    "goal_steps": profile.daily_goal_steps,
                    "is_goal_completed": False,
                },
                status=status.HTTP_200_OK,
            )

        if daily_steps.goal_steps != profile.daily_goal_steps:
            daily_steps.goal_steps = profile.daily_goal_steps
            daily_steps.save(update_fields=["goal_steps", "updated_at"])

        return Response(
            DailyStepsSerializer(daily_steps).data,
            status=status.HTTP_200_OK,
        )


class FriendsLeaderboardApi(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Sum  # чтобы не править импорты наверху

        today, error_response = _requested_steps_date(request)
        if error_response is not None:
            return error_response

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

        completed_dates = set(
            row["date"]
            for row in (
                DailySteps.objects
                .filter(user=user)
                .values("date", "steps", "goal_steps")
            )
            if row["steps"] >= row["goal_steps"]
        )

        streak = 0
        current_day = today if today in completed_dates else today - timedelta(days=1)

        while current_day in completed_dates:
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

        defaults = dict(serializer.validated_data)
        defaults["movement_state"] = blank_to_none(defaults.get("movement_state"))
        defaults["movement_kind"] = (
            normalize_movement_kind(defaults.get("movement_kind") or defaults.get("movement_state"))
            or "unknown"
        )
        confidence_score = clamp_confidence_score(defaults.get("confidence_score"))
        if confidence_score is None:
            confidence_score = confidence_score_for_point({
                "latitude": defaults["latitude"],
                "longitude": defaults["longitude"],
                "horizontal_accuracy": defaults.get("horizontal_accuracy"),
                "speed": defaults.get("speed"),
                "movement_state": defaults.get("movement_state"),
                "movement_kind": defaults.get("movement_kind"),
                "steps_delta": None,
                "recorded_at_dt": timezone.now(),
            })
        defaults["confidence_score"] = confidence_score
        defaults["signal_quality"] = (
            blank_to_none(defaults.get("signal_quality"))
            or signal_quality_from_score(defaults["confidence_score"])
        )

        previous_live = UserLiveLocation.objects.filter(user=request.user).first()
        if previous_live and defaults["confidence_score"] < 35:
            jump_distance = distance_meters(
                {
                    "latitude": previous_live.latitude,
                    "longitude": previous_live.longitude,
                },
                {
                    "latitude": defaults["latitude"],
                    "longitude": defaults["longitude"],
                },
            )
            accuracy = defaults.get("horizontal_accuracy") or 0
            max_reasonable_jump = max(250, accuracy * 0.8)

            if jump_distance > max_reasonable_jump:
                defaults["latitude"] = previous_live.latitude
                defaults["longitude"] = previous_live.longitude
                defaults["signal_quality"] = "poor"
                defaults["movement_kind"] = "signal_lost"

        obj, _ = UserLiveLocation.objects.update_or_create(
            user=request.user,
            defaults=defaults,
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

        fresh_after = timezone.now() - timedelta(hours=24)
        precise_after = timezone.now() - timedelta(minutes=5)

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

            signal_quality = live.signal_quality
            movement_kind = live.movement_kind

            if live.updated_at < precise_after:
                signal_quality = "poor"
                movement_kind = "signal_lost"

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "latitude": live.latitude,
                "longitude": live.longitude,
                "horizontal_accuracy": live.horizontal_accuracy,
                "confidence_score": live.confidence_score,
                "movement_state": live.movement_state,
                "movement_kind": movement_kind,
                "signal_quality": signal_quality,
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

        track_points = []
        affected_days = set()
        for item in serializer.validated_data["points"]:
            recorded_at = item["recorded_at"]
            day = timezone.localtime(recorded_at).date()
            movement_kind = (
                normalize_movement_kind(item.get("movement_kind") or item.get("movement_state"))
                or "unknown"
            )

            track_points.append(UserTrackPoint(
                user_id=request.user.id,
                latitude=item["latitude"],
                longitude=item["longitude"],
                horizontal_accuracy=item.get("horizontal_accuracy"),
                speed=item.get("speed"),
                course=item.get("course"),
                movement_state=blank_to_none(item.get("movement_state")),
                movement_kind=movement_kind,
                break_reason=normalize_break_reason(item.get("break_reason")),
                confidence_score=clamp_confidence_score(item.get("confidence_score")),
                steps_delta=item.get("steps_delta"),
                recorded_at=recorded_at,
                day=day,
            ))
            affected_days.add(day)

        if track_points:
            UserTrackPoint.objects.bulk_create(
                track_points,
                batch_size=TRACK_POINTS_BULK_CREATE_BATCH_SIZE,
            )

        rebuilt_days = []
        for day in affected_days or {timezone.localdate()}:
            try:
                if rebuild_user_matched_segments_throttled(request.user, day):
                    rebuilt_days.append(day.isoformat())
            except (DatabaseError, IntegrityError) as exc:
                print("Matched track rebuild skipped after upload:", exc)

        return Response(
            {
                "created": len(track_points),
                "matched_rebuilt_days": rebuilt_days,
            },
            status=status.HTTP_200_OK,
        )


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

        data = [public_track_point_dict(p) for p in qs]

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
            grouped[point.user_id].append(public_track_point_dict(point))

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

        if matched_segments_are_stale(request.user, day):
            try:
                rebuild_user_matched_segments_throttled(request.user, day, force=True)
            except (DatabaseError, IntegrityError) as exc:
                print("Matched track rebuild skipped before fetch:", exc)

        qs = MatchedTrackSegment.objects.filter(
            user=request.user,
            day=day
        ).order_by("started_at")

        data = [matched_segment_dict(s) for s in qs]

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
            grouped[s.user_id].append(matched_segment_dict(s))

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
        groups = list(
            Group.objects
            .filter(memberships__user=request.user)
            .prefetch_related("memberships")
            .order_by("name")
        )
        context = {
            "request": request,
            "group_list_stats": build_group_list_stats(groups, request.user.id),
        }

        return Response(
            GroupListSerializer(groups, many=True, context=context).data,
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
        freshness_limit = now - timedelta(hours=24)
        precise_after = now - timedelta(minutes=5)

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
            signal_quality = loc.signal_quality
            movement_kind = loc.movement_kind

            if loc.updated_at < precise_after:
                signal_quality = "poor"
                movement_kind = "signal_lost"

            result.append({
                "user_id": user.id,
                "username": user.username,
                "avatar_url": _avatar_url(request, user),
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "horizontal_accuracy": loc.horizontal_accuracy,
                "confidence_score": loc.confidence_score,
                "movement_state": loc.movement_state,
                "movement_kind": movement_kind,
                "signal_quality": signal_quality,
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
            grouped[s.user_id].append(matched_segment_dict(s))

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
        today, error_response = _requested_steps_date(request)
        if error_response is not None:
            return error_response

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

        today, error_response = _requested_steps_date(request)
        if error_response is not None:
            return error_response

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
