/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.util;

public class Holder<T> {
	
	private T heldObject = null;
	
	public Holder() {
	}

	public Holder(T value) {
		this.heldObject = value;
	}

	public T get() {
		return heldObject;
	}

	public void set(T toHoldObject) {
		this.heldObject = toHoldObject;
	}
	
	public void clear() {
		heldObject = null;
	}

}
