import '../../../models/patient.dart';

enum PatientOperationFeedbackType {
  success,
  error,
}

class PatientOperationFeedback {
  const PatientOperationFeedback({
    required this.message,
    required this.type,
    required this.duration,
  });

  final String message;
  final PatientOperationFeedbackType type;
  final Duration duration;
}

class PatientOperationFeedbackService {
  const PatientOperationFeedbackService._();

  static PatientOperationFeedback saveSuccess(Patient patient) {
    return PatientOperationFeedback(
      message: patient.id != null ? '患者信息更新成功' : '患者添加成功',
      type: PatientOperationFeedbackType.success,
      duration: const Duration(seconds: 2),
    );
  }

  static PatientOperationFeedback saveFailure(Object error) {
    return PatientOperationFeedback(
      message: '添加患者失败: $error',
      type: PatientOperationFeedbackType.error,
      duration: const Duration(seconds: 4),
    );
  }

  static PatientOperationFeedback updateSuccess() {
    return const PatientOperationFeedback(
      message: '患者信息已更新',
      type: PatientOperationFeedbackType.success,
      duration: Duration(seconds: 2),
    );
  }

  static PatientOperationFeedback updateFailure(Object error) {
    return PatientOperationFeedback(
      message: '更新患者信息失败: $error',
      type: PatientOperationFeedbackType.error,
      duration: const Duration(seconds: 4),
    );
  }

  static PatientOperationFeedback deleteFailure(Object error) {
    return PatientOperationFeedback(
      message: '删除患者失败: $error',
      type: PatientOperationFeedbackType.error,
      duration: const Duration(seconds: 4),
    );
  }
}
