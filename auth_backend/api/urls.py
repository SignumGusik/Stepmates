from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from . import views


app_name = "api"

urlpatterns = [
    path("register/", views.RegisterAppUser.as_view(), name="registration"),
    path("activate_account/<str:token>/", views.ActivateAccount.as_view(), name="user_activation"),
    path("login_data/", views.LoginDataApi.as_view()),

    path("register/verify/", views.RegisterVerifyApi.as_view(), name="register_verify"),
    path("register/resend/", views.RegisterResendApi.as_view(), name="register_resend"),

    path("password-reset/", views.PasswordResetRequestApi.as_view(), name="password_reset"),
    path("password-reset/confirm/", views.PasswordResetConfirmApi.as_view(), name="password_reset_confirm"),
path("password-reset/verify/", views.PasswordResetVerifyApi.as_view(), name="password_reset_verify"),

    path("auth/token/", views.EmailTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh", TokenRefreshView.as_view()),

    path("users/", views.UserSearchApi.as_view(), name="user-search"),
    path("users/<int:user_id>/card/", views.UserCardApi.as_view(), name="user-card"),

    path("friend-requests/", views.FriendRequestCreateApi.as_view()),
    path("friend-requests/incoming/", views.IncomingFriendRequestsApi.as_view()),
    path("friend-requests/outgoing/", views.OutgoingFriendRequestsApi.as_view()),
    path("friend-requests/<int:user_id>/cancel/", views.CancelOutgoingFriendRequestApi.as_view()),
    path("friend-requests/<int:pk>/accept/", views.AcceptFriendRequestApi.as_view()),
    path("friend-requests/<int:pk>/reject/", views.RejectFriendRequestApi.as_view()),

    path("friends/", views.FriendsListApi.as_view()),
    path("friends/<int:user_id>/", views.RemoveFriendApi.as_view()),
    path("friends/leaderboard/", views.FriendsLeaderboardApi.as_view(), name="friends_leaderboard"),

    path("steps/sync/", views.DailyStepsSyncApi.as_view(), name="steps_sync"),
    path("steps/me/today/", views.MyTodayStepsApi.as_view(), name="my_today_steps"),

    path("groups/", views.GroupsAPI.as_view(), name="groups"),
    path("groups/<int:group_id>/", views.GroupDetailAPI.as_view(), name="group_detail"),

    path("groups/<int:group_id>/members/", views.GroupAddMemberAPI.as_view(), name="group_add_member"),
    path("groups/<int:group_id>/members/<int:user_id>/", views.GroupRemoveMemberAPI.as_view(), name="group_remove_member"),

    path("groups/<int:group_id>/leave/", views.GroupLeaveAPI.as_view(), name="group_leave"),
    path("groups/<int:group_id>/leaderboard/", views.GroupLeaderboardAPI.as_view(), name="group_leaderboard"),
    path("groups/<int:group_id>/avatar/", views.GroupAvatarAPI.as_view(), name="group_avatar"),
    path("groups/<int:group_id>/members/<int:user_id>/promote/", views.GroupPromoteAdminAPI.as_view(), name="group_promote_admin"),
    path("groups/<int:group_id>/members/<int:user_id>/demote/", views.GroupDemoteAdminAPI.as_view(), name="group_demote_admin"),
    path("groups/<int:group_id>/delete/", views.GroupDeleteAPI.as_view(), name="group_delete"),
    path("profile/me/", views.MyProfileApi.as_view(), name="my_profile"),
    path("profile/avatar/", views.ProfileAvatarApi.as_view(), name="profile_avatar"),
    path("profile/username/", views.SetUsernameApi.as_view(), name="set_username"),

    path("map/live-location/", views.MyLiveLocationApi.as_view(), name="my-live-location"),
    path("map/friends-live/", views.FriendsLiveLocationApi.as_view(), name="friends-live"),

    path("map/track-points/", views.MyTrackPointsApi.as_view(), name="my-track-points"),
    path("map/my-track/", views.MyTrackApi.as_view(), name="my-track"),
    path("map/friends-tracks/", views.FriendsTracksApi.as_view(), name="friends-tracks"),
    path("map/my-matched-track/", views.MyMatchedTrackApi.as_view(), name="my-matched-track"),
    path("map/friends-matched-tracks/", views.FriendsMatchedTracksApi.as_view(), name="friends-matched-tracks"),
    path("notifications/", views.NotificationsAPI.as_view(), name="notifications"),
    path(
        "group-invites/<int:invite_id>/accept/",
        views.AcceptGroupInviteAPI.as_view(),
        name="group_invite_accept"
    ),
    path(
        "group-invites/<int:invite_id>/reject/",
        views.RejectGroupInviteAPI.as_view(),
        name="group_invite_reject"
    ),
    path(
        "notifications/friend-request-accepted/<int:request_id>/dismiss/",
        views.DismissFriendAcceptedNotificationAPI.as_view(),
        name="friend_request_accepted_dismiss"
    ),
    path("map/groups/", views.MapGroupsApi.as_view(), name="map-groups"),
    path("map/groups/<int:group_id>/live/", views.GroupLiveLocationApi.as_view(), name="group-live"),
    path("map/groups/<int:group_id>/matched-tracks/", views.GroupMatchedTracksApi.as_view(), name="group-matched-tracks"),
    path("map/ranking/", views.MapFriendsRankingApi.as_view(), name="map-friends-ranking"),
    path("map/groups/<int:group_id>/ranking/", views.MapGroupRankingApi.as_view(), name="map-group-ranking"),
]

