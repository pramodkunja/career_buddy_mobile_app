import 'dart:typed_data';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/certification_subject.dart';
import '../../domain/entities/certifications_status.dart';
import '../../domain/repositories/certifications_repository.dart';
import '../datasources/certifications_remote_datasource.dart';

class CertificationsRepositoryImpl implements CertificationsRepository {
  CertificationsRepositoryImpl(this._remote);

  final CertificationsRemoteDataSource _remote;

  @override
  Future<Result<CertificationsStatus>> getStatus() async {
    try {
      return Success(await _remote.getStatus());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<CertificationSubject>> generateCertificate({required String subject, required String name}) async {
    try {
      return Success(await _remote.generateCertificate(subject: subject, name: name));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<CertificationSubject>> regenerateCertificate({required String subject, required String name}) async {
    try {
      return Success(await _remote.regenerateCertificate(subject: subject, name: name));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<Uint8List>> downloadCertificateBytes(String subject) async {
    try {
      return Success(await _remote.downloadCertificateBytes(subject));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
