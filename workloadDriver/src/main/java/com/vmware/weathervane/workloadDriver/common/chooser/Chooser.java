/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.chooser;

import java.util.List;
import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.util.Holder;

public class Chooser<T> {
	private static final Logger logger = LoggerFactory.getLogger(Chooser.class);

	List<T> choices;
	Holder<T> chosen;
	Random randGen;

	public Chooser(List<T> choices, Holder<T> choosen, Random randGen) {
		this.choices = choices;
		this.chosen = choosen;
		this.randGen = randGen;
	}

	public void chooseRandom() {
		logger.debug("chooseRandom numChoices = " + choices.size());
		int numChoices = choices.size();
		double randVal = randGen.nextDouble();

		int choice = (int) Math.floor(randVal * numChoices);
		logger.debug("chooseRandom numChoices = " + choices.size() + ", randVal = " + randVal
				+ ", choice = " + choice);
		synchronized (chosen) {
			chosen.set(choices.get(choice));
		}
	}

	public void setChosen(T choice) {
		logger.debug("setChosen ");
		synchronized (chosen) {
			chosen.set(choice);
		}
	}

}
