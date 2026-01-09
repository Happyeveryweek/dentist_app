import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 牙科图标库 - 使用FontAwesome图标
class DentalIcons {
  // 基础图标 - 使用FontAwesome图标
  static const IconData tooth = FontAwesomeIcons.tooth; // 真正的牙齿图标！
  static const IconData teeth = FontAwesomeIcons.teeth;
  static const IconData teethOpen = FontAwesomeIcons.teethOpen;
  
  // 备用牙齿图标 - 使用Flutter内置图标
  static const IconData toothFallback = Icons.medical_services; // 备用图标
  static const IconData teethFallback = Icons.medical_services; // 备用图标
  
  static const IconData stethoscope = FontAwesomeIcons.stethoscope;
  static const IconData heartPulse = FontAwesomeIcons.heartPulse;
  static const IconData userDoctor = FontAwesomeIcons.userDoctor;
  static const IconData userNurse = FontAwesomeIcons.userNurse;
  static const IconData hospitalUser = FontAwesomeIcons.hospitalUser;
  static const IconData hospital = FontAwesomeIcons.hospital;
  static const IconData kitMedical = FontAwesomeIcons.kitMedical;
  static const IconData pills = FontAwesomeIcons.pills;
  static const IconData syringe = FontAwesomeIcons.syringe;
  static const IconData thermometer = FontAwesomeIcons.thermometer;
  static const IconData bandage = FontAwesomeIcons.bandage;
  static const IconData microscope = FontAwesomeIcons.microscope;
  static const IconData xRay = FontAwesomeIcons.xRay;
  static const IconData clipboard = FontAwesomeIcons.clipboard;
  static const IconData clipboardUser = FontAwesomeIcons.clipboardUser;
  static const IconData calendarCheck = FontAwesomeIcons.calendarCheck;
  static const IconData calendarPlus = FontAwesomeIcons.calendarPlus;
  static const IconData clockRotateLeft = FontAwesomeIcons.clockRotateLeft;
  static const IconData fileInvoiceDollar = FontAwesomeIcons.fileInvoiceDollar;
  static const IconData chartLine = FontAwesomeIcons.chartLine;
  static const IconData chartPie = FontAwesomeIcons.chartPie;
  static const IconData shoppingCart = FontAwesomeIcons.shoppingCart;
  
  // 替代图标（使用FontAwesome图标）
  static const IconData userMd = FontAwesomeIcons.userMd;
  static const IconData userPlus = FontAwesomeIcons.userPlus;
  static const IconData medkit = FontAwesomeIcons.medkit;
  static const IconData heartbeat = FontAwesomeIcons.heartbeat;
  static const IconData ambulance = FontAwesomeIcons.ambulance;
  static const IconData wheelchair = FontAwesomeIcons.wheelchair;
  static const IconData bed = FontAwesomeIcons.bed;
  static const IconData procedures = FontAwesomeIcons.procedures;
  static const IconData prescriptionBottle = FontAwesomeIcons.prescriptionBottle;
  
  // 牙科治疗相关图标（使用Material Icons）
  static const IconData cleaning = Icons.cleaning_services; // 洁治
  static const IconData filling = Icons.build; // 充填
  static const IconData crown = Icons.star; // 冠修复
  static const IconData bridge = Icons.link; // 桥修复
  static const IconData extraction = Icons.content_cut; // 拔牙
  static const IconData orthodontics = Icons.straighten; // 正畸
  static const IconData implant = Icons.construction; // 种植
  static const IconData rootCanal = Icons.linear_scale; // 根管治疗
  static const IconData dentures = Icons.medical_services; // 义齿
  static const IconData whitening = Icons.star_border; // 美白
  static const IconData periodontics = Icons.nature; // 牙周治疗
  static const IconData surgery = Icons.medical_services; // 手术
  
  // 状态图标（使用Material Icons）
  static const IconData completed = Icons.check_circle;
  static const IconData pending = Icons.schedule;
  static const IconData cancelled = Icons.cancel;
  static const IconData warning = Icons.warning;
  static const IconData emergency = Icons.error;
  
  // 性别图标（使用Material Icons）
  static const IconData male = Icons.male;
  static const IconData female = Icons.female;
  static const IconData child = Icons.child_care;
  
  // 获取治疗类型对应的图标
  static IconData getTreatmentIcon(String treatmentType) {
    switch (treatmentType.toLowerCase()) {
      case '洁治':
      case '洗牙':
        return cleaning;
      case '充填':
      case '补牙':
        return filling;
      case '冠修复':
      case '牙冠':
        return crown;
      case '桥修复':
        return bridge;
      case '拔牙':
      case '拔除':
        return extraction;
      case '正畸':
      case '矫正':
        return orthodontics;
      case '种植':
      case '植牙':
        return implant;
      case '根管治疗':
      case '根管':
        return rootCanal;
      case '义齿':
      case '假牙':
        return dentures;
      case '美白':
        return whitening;
      case '牙周治疗':
        return periodontics;
      case '手术':
        return surgery;
      default:
        return Icons.medical_services;
    }
  }
  
  // 获取状态对应的图标
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case '已完成':
      case '完成':
        return completed;
      case '待处理':
      case '待办':
        return pending;
      case '已取消':
      case '取消':
        return cancelled;
      case '警告':
        return warning;
      case '紧急':
        return emergency;
      default:
        return pending;
    }
  }
  
  // 获取性别对应的图标
  static IconData getGenderIcon(String gender) {
    switch (gender.toLowerCase()) {
      case '男':
      case 'male':
        return male;
      case '女':
      case 'female':
        return female;
      case '儿童':
      case 'child':
        return child;
      default:
        return Icons.person;
    }
  }
}
