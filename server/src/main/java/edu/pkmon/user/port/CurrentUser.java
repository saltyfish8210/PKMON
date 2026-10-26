package edu.pkmon.user.port;

/** Resolves identity for the current request; throws AuthFailure when no valid identity exists. */
@FunctionalInterface
public interface CurrentUser {
    String currentUserId();
}
