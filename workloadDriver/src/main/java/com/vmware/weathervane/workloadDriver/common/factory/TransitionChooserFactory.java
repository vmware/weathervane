/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.factory;

import java.util.Map;
import java.util.Random;

import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooser;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;


public interface TransitionChooserFactory {

	Map<String, TransitionChooser> getTransitionChoosers(Random random, Behavior behavior);
}
