// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class ExportService {
  /// Export attendance data to CSV format
  Future<String> exportToCSV({
    required List<Map<String, dynamic>> reportData,
    required String fileName,
  }) async {
    try {
      final List<String> csvLines = [];
      
      // Add headers
      csvLines.add('Employee Name,Email,Position,Date,Status,Check In,Check Out,Total Hours');
      
      // Add data rows
      for (final row in reportData) {
        final List<String> csvRow = [
          _escapeCSVField(row['employee_name']?.toString() ?? ''),
          _escapeCSVField(row['email']?.toString() ?? ''),
          _escapeCSVField(row['position']?.toString() ?? ''),
          _escapeCSVField(row['date']?.toString() ?? ''),
          _escapeCSVField(row['status']?.toString() ?? ''),
          _escapeCSVField(row['check_in']?.toString() ?? ''),
          _escapeCSVField(row['check_out']?.toString() ?? ''),
          _escapeCSVField(row['total_hours']?.toString() ?? ''),
        ];
        csvLines.add(csvRow.join(','));
      }
      
      final csvContent = csvLines.join('\n');
      final filePath = await _saveToFile(csvContent, '$fileName.csv');
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Export attendance data to PDF format
  Future<String> exportToPDF({
    required Map<String, dynamic> reportData,
    required String fileName,
  }) async {
    try {
      final pdf = pw.Document();
      final summary = reportData['summary'] as Map<String, dynamic>? ?? {};
      final employeeDetails = reportData['employee_details'] as Map<String, dynamic>? ?? {};

      // Add cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Generated on: ${DateTime.now().toString().split('.')[0]}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      if (reportData['period'] != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Period: ${reportData['period']['start']} to ${reportData['period']['end']}',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Summary Section
                pw.Text(
                  'Summary Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Total Employees', summary['total_employees']?.toString() ?? '0'),
                      _buildSummaryRow('Present Days', summary['total_present_days']?.toString() ?? '0'),
                      _buildSummaryRow('Late Days', summary['total_late_days']?.toString() ?? '0'),
                      _buildSummaryRow('Absent Days', summary['total_absent_days']?.toString() ?? '0'),
                      _buildSummaryRow('Average Attendance Rate', '${summary['average_attendance_rate']?.toStringAsFixed(1) ?? '0.0'}%'),
                      _buildSummaryRow('Average Punctuality Rate', '${summary['average_punctuality_rate']?.toStringAsFixed(1) ?? '0.0'}%'),
                      _buildSummaryRow('Total Hours Worked', '${summary['total_hours_worked']?.toStringAsFixed(1) ?? '0.0'} hrs'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Add detailed data page if there are employees
      if (employeeDetails.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Employee Details',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Employee table
                  pw.Table.fromTextArray(
                    headers: ['Name', 'Position', 'Present', 'Late', 'Absent', 'Attendance %', 'Hours'],
                    data: employeeDetails.entries.map((entry) {
                      final data = entry.value as Map<String, dynamic>;
                      return [
                        data['name']?.toString() ?? '',
                        data['position']?.toString() ?? '',
                        data['present_days']?.toString() ?? '0',
                        data['late_days']?.toString() ?? '0',
                        data['absent_days']?.toString() ?? '0',
                        '${data['attendance_percentage']?.toStringAsFixed(1) ?? '0.0'}%',
                        '${data['total_hours']?.toStringAsFixed(1) ?? '0.0'}',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blue600,
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.all(8),
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save PDF
      final pdfBytes = await pdf.save();
      final filePath = await _saveBytesToFile(pdfBytes, '$fileName.pdf');
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Build summary row for PDF
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  /// Escape CSV field to handle commas and quotes
  String _escapeCSVField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Save string content to file
  Future<String> _saveToFile(String content, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/attendance_reports');
      
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      
      final file = File('${reportsDir.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save bytes to file
  Future<String> _saveBytesToFile(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/attendance_reports');
      
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      
      final file = File('${reportsDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  /// Generate quick daily report data
  List<Map<String, dynamic>> generateDailyReportData({
    required List<AttendanceModel> attendanceList,
    required List<UserModel> employees,
  }) {
    final Map<String, UserModel> employeeMap = {
      for (final emp in employees) emp.userId: emp
    };

    return attendanceList.map((attendance) {
      final employee = employeeMap[attendance.userId];
      return {
        'employee_name': employee?.name ?? 'Unknown',
        'email': employee?.email ?? 'Unknown',
        'position': employee?.position ?? 'Unknown',
        'date': attendance.date.toString().split(' ')[0],
        'status': attendance.status,
        'check_in': attendance.checkInTime?.toString().split(' ')[1].substring(0, 5) ?? '-',
        'check_out': attendance.checkOutTime?.toString().split(' ')[1].substring(0, 5) ?? '-',
        'total_hours': (attendance.totalMinutes / 60).toStringAsFixed(1),
      };
    }).toList();
  }

  /// Get available export formats
  List<Map<String, String>> get availableFormats => [
    {'key': 'csv', 'name': 'CSV (Excel)', 'extension': 'csv'},
    {'key': 'pdf', 'name': 'PDF Document', 'extension': 'pdf'},
  ];

  /// Generate filename with timestamp
  String generateFileName(String prefix) {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return '${prefix}_$timestamp';
  }
}
