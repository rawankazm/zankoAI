import 'api_error.dart';

/// Generic resource wrapper representing distinct UI and asynchronous states.
sealed class ResourceState<T> {
  const ResourceState();

  const factory ResourceState.initial() = InitialState<T>;
  const factory ResourceState.loading({double? progress}) = LoadingState<T>;
  const factory ResourceState.success(T data) = SuccessState<T>;
  const factory ResourceState.error(ApiError error) = ErrorState<T>;

  bool get isInitial => this is InitialState<T>;
  bool get isLoading => this is LoadingState<T>;
  bool get isSuccess => this is SuccessState<T>;
  bool get isError => this is ErrorState<T>;

  T? get dataOrNull {
    final self = this;
    return self is SuccessState<T> ? self.data : null;
  }

  ApiError? get errorOrNull {
    final self = this;
    return self is ErrorState<T> ? self.error : null;
  }

  String? get errorMessage => errorOrNull?.message;

  R when<R>({
    required R Function() initial,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(ApiError error) error,
  }) {
    final self = this;
    if (self is InitialState<T>) return initial();
    if (self is LoadingState<T>) return loading(self.progress);
    if (self is SuccessState<T>) return success(self.data);
    if (self is ErrorState<T>) return error(self.error);
    throw StateError('Unhandled state $self');
  }

  R maybeWhen<R>({
    R Function()? initial,
    R Function(double? progress)? loading,
    R Function(T data)? success,
    R Function(ApiError error)? error,
    required R Function() orElse,
  }) {
    final self = this;
    if (self is InitialState<T> && initial != null) {
      return initial();
    }
    if (self is LoadingState<T> && loading != null) {
      return loading(self.progress);
    }
    if (self is SuccessState<T> && success != null) {
      return success(self.data);
    }
    if (self is ErrorState<T> && error != null) {
      return error(self.error);
    }
    return orElse();
  }
}

class InitialState<T> extends ResourceState<T> {
  const InitialState();
  @override
  String toString() => 'ResourceState.initial()';
}

class LoadingState<T> extends ResourceState<T> {
  final double? progress;
  const LoadingState({this.progress});
  @override
  String toString() => 'ResourceState.loading(progress: $progress)';
}

class SuccessState<T> extends ResourceState<T> {
  final T data;
  const SuccessState(this.data);
  @override
  String toString() => 'ResourceState.success(data: $data)';
}

class ErrorState<T> extends ResourceState<T> {
  final ApiError error;
  const ErrorState(this.error);
  @override
  String toString() => 'ResourceState.error(error: $error)';
}
