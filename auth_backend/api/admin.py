from django.contrib import admin

# Register your models here.
from .models import Group, GroupMembership, UserProfile


@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "created_by", "created_at")
    search_fields = ("name",)
    list_filter = ("created_at",)


@admin.register(GroupMembership)
class GroupMembershipAdmin(admin.ModelAdmin):
    list_display = ("id", "group", "user", "is_admin", "added_by", "created_at")
    list_filter = ("is_admin", "created_at")
    search_fields = ("group__name", "user__username", "user__email")


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "avatar", "avatar_updated_at", "created_at", "updated_at")
    search_fields = ("user__username", "user__email")
    readonly_fields = ("created_at", "updated_at", "avatar_updated_at")
