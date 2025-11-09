class CustomResponse<T> {
  final bool status;
  final T data;
  final String? message;

  CustomResponse({
    required this.status,
    required this.data,
    this.message,
  });
}
