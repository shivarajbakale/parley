import 'package:flutter/material.dart';
import 'package:parley_android/data/api_exceptions.dart';

/// What to show a person when something failed.
///
/// Three fields because an error state is three decisions: which glyph names
/// the *kind* of failure, what sentence says what happened and what to do, and
/// what the button offers. A screen that assembles those itself assembles them
/// differently from the screen next to it.
typedef ErrorCopy = ({IconData icon, String message, String actionLabel});

/// Turns any thrown object into something a person can read and act on.
///
/// The rule this exists to enforce: **an exception is never shown to a user.**
/// `'$error'` in a message is the shortest path from a network blip to
/// `ClientException with SocketException: Failed host lookup: 'api.example.com'`
/// on a phone screen, and it is a path every screen finds independently.
///
/// The mapping keys off the typed exceptions [dioCall] already produces, so the
/// classification is the one the data layer made rather than a second one
/// guessed from a message string. Anything unrecognised gets the general
/// sentence rather than its own text — an error the app did not anticipate is
/// exactly the error whose wording nobody has read.
///
/// Copy shape, from Apple's and Material's guidance both: say what happened in
/// the user's terms, then what they can do. Never "Invalid input"; never a
/// status code; never an apology in place of an instruction.
ErrorCopy errorCopyFor(Object error) {
  if (error is NetworkException) {
    return (
      icon: Icons.wifi_off_outlined,
      message: "Can't reach the server. Check your connection and try again.",
      actionLabel: 'Try again',
    );
  }

  if (error is NotFoundException) {
    return (
      icon: Icons.search_off_outlined,
      message: "This isn't here any more. It may have been moved or removed.",
      actionLabel: 'Refresh',
    );
  }

  if (error is ValidationException) {
    // The only branch that carries the server's own words, because a 400 is
    // the one case where the server is describing the user's input rather
    // than its own internals — "Email address is already registered" is copy
    // written for a person, and replacing it with a generic line loses the
    // only thing that would let them fix it.
    return (
      icon: Icons.error_outline,
      message: error.message,
      actionLabel: 'Try again',
    );
  }

  if (error is ServerException) {
    return (
      icon: Icons.cloud_off_outlined,
      message: 'Something went wrong on our end. Try again in a moment.',
      actionLabel: 'Try again',
    );
  }

  if (error is ApiException && error.statusCode == 401) {
    return (
      icon: Icons.lock_outline,
      message: 'Your session has expired. Sign in again to continue.',
      actionLabel: 'Sign in',
    );
  }

  return (
    icon: Icons.error_outline,
    message: "Something went wrong and we couldn't finish that. Try again.",
    actionLabel: 'Try again',
  );
}
