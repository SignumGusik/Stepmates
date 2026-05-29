from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from .models import MatchedTrackSegment, UserTrackPoint
from .views import (
    break_reason_for_point,
    classify_signal_quality,
    confidence_score_for_point,
    distance_meters,
    matching_confidence_from_score,
    movement_kind_for_point,
    rebuild_user_matched_segments,
    should_start_new_segment,
    signal_quality_from_score,
    smooth_points,
)

User = get_user_model()


class MapQualityHelperTests(TestCase):
    def test_distance_meters_is_zero_for_same_point(self):
        point = {"latitude": 55.751, "longitude": 37.618}
        self.assertEqual(distance_meters(point, point), 0)

    def test_quality_buckets_match_client_contract(self):
        self.assertEqual(signal_quality_from_score(90), "good")
        self.assertEqual(signal_quality_from_score(60), "weak")
        self.assertEqual(signal_quality_from_score(20), "poor")
        self.assertEqual(matching_confidence_from_score(90), "high")
        self.assertEqual(matching_confidence_from_score(60), "medium")
        self.assertEqual(matching_confidence_from_score(20), "low")

    def test_movement_kind_prefers_explicit_value_then_steps(self):
        self.assertEqual(movement_kind_for_point({"movement_kind": "automotive"}), "transport")
        self.assertEqual(movement_kind_for_point({"movement_state": "cycling"}), "transport")
        self.assertEqual(movement_kind_for_point({"steps_delta": 4}), "walking")
        self.assertEqual(movement_kind_for_point({}), "unknown")

    def test_confidence_score_uses_explicit_value_when_present(self):
        point = {"confidence_score": 123, "recorded_at_dt": timezone.now()}
        self.assertEqual(confidence_score_for_point(point), 100)

    def test_break_reason_detects_poor_accuracy_and_transport(self):
        poor_accuracy = {
            "latitude": 55.751,
            "longitude": 37.618,
            "horizontal_accuracy": 120,
            "speed": 1,
            "recorded_at_dt": timezone.now(),
        }
        transport = {
            "latitude": 55.751,
            "longitude": 37.618,
            "movement_kind": "transport",
            "recorded_at_dt": timezone.now(),
        }

        self.assertEqual(break_reason_for_point(poor_accuracy), "poor_accuracy")
        self.assertEqual(break_reason_for_point(transport), "vehicle_jump")

    def test_smoothing_preserves_unreliable_point_coordinates(self):
        points = [
            {"latitude": 10.0, "longitude": 10.0, "confidence_score": 90, "movement_kind": "walking"},
            {"latitude": 20.0, "longitude": 20.0, "confidence_score": 20, "movement_kind": "walking", "break_reason": "poor_accuracy"},
            {"latitude": 30.0, "longitude": 40.0, "confidence_score": 90, "movement_kind": "walking"},
        ]

        result = smooth_points(points)

        self.assertEqual(result[1]["latitude"], 20.0)
        self.assertEqual(result[1]["longitude"], 20.0)
        self.assertEqual(result[1]["break_reason"], "poor_accuracy")

    def test_segment_split_detects_time_gap(self):
        now = timezone.now()
        previous = {"recorded_at_dt": now, "movement_kind": "walking", "break_reason": None}
        current = {"recorded_at_dt": now + timedelta(minutes=3), "movement_kind": "walking", "break_reason": None}

        self.assertTrue(should_start_new_segment(previous, current))


class MatchedTrackRebuildTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="tracker", email="tracker@example.com", password="pass12345")
        self.day = timezone.localdate()

    def _create_point(self, seconds, movement_kind="walking", confidence_score=92, break_reason=None, speed=1.2):
        return UserTrackPoint.objects.create(
            user=self.user,
            latitude=55.751 + seconds * 0.000001,
            longitude=37.618 + seconds * 0.000001,
            horizontal_accuracy=8,
            speed=speed,
            course=90,
            movement_state=movement_kind,
            movement_kind=movement_kind,
            break_reason=break_reason,
            confidence_score=confidence_score,
            steps_delta=4,
            recorded_at=timezone.now() + timedelta(seconds=seconds),
            day=self.day,
        )

    def test_rebuild_creates_matched_walking_segment(self):
        self._create_point(0)
        self._create_point(10)

        count = rebuild_user_matched_segments(self.user, self.day)

        self.assertEqual(count, 1)
        segment = MatchedTrackSegment.objects.get(user=self.user, day=self.day)
        self.assertEqual(segment.status, MatchedTrackSegment.STATUS_MATCHED)
        self.assertEqual(segment.signal_quality, "good")
        self.assertEqual(segment.matching_confidence, "high")
        self.assertEqual(segment.movement_kind, "walking")
        self.assertIsNone(segment.break_reason)
        self.assertEqual(len(segment.display_points), 2)

    def test_rebuild_marks_transport_segment_as_fallback(self):
        self._create_point(0, movement_kind="transport", confidence_score=65, speed=12)
        self._create_point(10, movement_kind="transport", confidence_score=62, speed=12)

        count = rebuild_user_matched_segments(self.user, self.day)

        self.assertEqual(count, 1)
        segment = MatchedTrackSegment.objects.get(user=self.user, day=self.day)
        self.assertEqual(segment.status, MatchedTrackSegment.STATUS_FALLBACK)
        self.assertEqual(segment.break_reason, "vehicle_jump")
        self.assertEqual(segment.movement_kind, "transport")

    def test_classify_signal_quality_averages_points(self):
        self.assertEqual(classify_signal_quality([{"confidence_score": 90}, {"confidence_score": 80}]), "good")
        self.assertEqual(classify_signal_quality([{"confidence_score": 50}, {"confidence_score": 40}]), "weak")
        self.assertEqual(classify_signal_quality([{"confidence_score": 20}, {"confidence_score": 25}]), "poor")
