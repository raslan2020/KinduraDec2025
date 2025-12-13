from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, UserToken, UserJSON


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    """
    Custom admin for User model
    """
    list_display = ['email', 'username', 'first_name', 'last_name', 'is_active', 'date_joined']
    list_filter = ['is_active', 'is_staff', 'is_superuser', 'gender', 'date_joined']
    search_fields = ['email', 'username', 'first_name', 'last_name']
    ordering = ['-date_joined']
    
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('username', 'first_name', 'last_name', 'phone_number', 'age', 'gender', 'agent_conservation_choice' ,'language', 'address', 'terms_and_conditions')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'username', 'password1', 'password2'),
        }),
    )


@admin.register(UserJSON)
class UserJSONAdmin(admin.ModelAdmin):
    list_display = ['user', 'uploaded_at']
    search_fields = ['user__email']
    readonly_fields = ['uploaded_at', 'data']

@admin.register(UserToken)
class UserTokenAdmin(admin.ModelAdmin):
    """
    Admin for UserToken model
    """
    list_display = ['user', 'token', 'created_at', 'is_active']
    list_filter = ['is_active', 'created_at']
    search_fields = ['user__email', 'token']
    readonly_fields = ['token', 'created_at']
    ordering = ['-created_at']
