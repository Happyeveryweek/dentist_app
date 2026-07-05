import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/features/patients/services/patient_list_state_service.dart';
import 'package:dentist_app_windows/features/patients/services/patient_list_query_service.dart';
import 'package:dentist_app_windows/models/patient.dart';

Patient _makePatient({
  required int id,
  required String name,
  String gender = '男',
  int age = 30,
}) {
  return Patient(
    id: id,
    name: name,
    age: age,
    gender: gender,
    phone: '13800138000',
    firstVisitDate: DateTime(2026, 1, 1),
  );
}

void main() {
  group('患者管理-列表分页计算', () {
    test('总记录数为0时显示总页数为1', () {
      final result = PatientListStateService.computePagination(
        totalPatients: 0,
        patientsPerPage: 10,
      );
      expect(result.totalPages, 0);
      expect(result.displayTotalPages, 1);
    });

    test('总记录数能被每页条数整除时计算正确总页数', () {
      final result = PatientListStateService.computePagination(
        totalPatients: 30,
        patientsPerPage: 10,
      );
      expect(result.totalPages, 3);
      expect(result.displayTotalPages, 3);
    });

    test('总记录数不能被每页条数整除时向上取整', () {
      final result = PatientListStateService.computePagination(
        totalPatients: 25,
        patientsPerPage: 10,
      );
      expect(result.totalPages, 3);
      expect(result.displayTotalPages, 3);
    });
  });

  group('患者管理-列表排序切换', () {
    test('点击当前排序字段时切换升降序', () {
      final result = PatientListStateService.computeSortChange(
        currentField: 'name',
        clickedField: 'name',
        currentAscending: true,
      );
      expect(result.sortField, 'name');
      expect(result.sortAscending, false);
    });

    test('点击新排序字段时默认降序', () {
      final result = PatientListStateService.computeSortChange(
        currentField: 'name',
        clickedField: 'age',
        currentAscending: true,
      );
      expect(result.sortField, 'age');
      expect(result.sortAscending, false);
    });
  });

  group('患者管理-列表状态构建', () {
    test('从分页结果构建列表状态', () {
      final pageResult = PatientListPageResult(
        patients: [
          _makePatient(id: 1, name: '张三'),
          _makePatient(id: 2, name: '李四'),
        ],
        totalCount: 2,
      );
      final state = PatientListStateService.fromPageResult(
        result: pageResult,
        searchQuery: '',
        isSearching: false,
      );
      expect(state.patients.length, 2);
      expect(state.totalPatients, 2);
      expect(state.isLoading, false);
      expect(state.hasSearchResults, false);
    });

    test('从高级搜索结果构建列表状态', () {
      final pageResult = PatientListPageResult(
        patients: [_makePatient(id: 1, name: '张三')],
        totalCount: 1,
      );
      final state = PatientListStateService.fromAdvancedSearchResult(
        result: pageResult,
        searchQuery: '张三',
      );
      expect(state.patients.length, 1);
      expect(state.totalPatients, 1);
      expect(state.isSearching, false);
      expect(state.hasSearchResults, true);
      expect(state.searchQuery, '张三');
    });
  });
}
