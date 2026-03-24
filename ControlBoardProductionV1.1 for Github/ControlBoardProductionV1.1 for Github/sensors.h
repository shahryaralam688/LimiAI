#pragma once
#include "globals.h"

uint32_t lastPower = 0;

void readPower() {
  busN = INA.getBusVoltage();
  shuN = INA.getShuntVoltage_mV();
  curN = INA.getCurrent_mA();
  powN = INA.getPower_mW();
}

void ina226gather() {
  uint32_t now = millis();
  if (now - lastPower >= 3000) {
    lastPower = now;
    readPower();
  }
}
