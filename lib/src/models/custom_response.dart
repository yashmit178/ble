class CustomResponse<T> {
  final bool status;
  final T data;

  CustomResponse({
    required this.status,
    required this.data,
  });
}
