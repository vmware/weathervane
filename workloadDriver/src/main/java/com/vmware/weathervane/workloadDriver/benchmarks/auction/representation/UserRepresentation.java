/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;

public class UserRepresentation extends Representation  implements Serializable{

	private static final long serialVersionUID = 1L;
	
	public enum UserState {
		REGISTERED, INCOMPLETE, DUPLICATE, NOPASSWORD
	};

	private Long id;
	private String username;
	private Float creditLimit;
	private String firstname;
	private String lastname;
	private String password;
	private String repeatPassword;
	private boolean enabled;
	private UserState state;
	private String authorities;

	public UserRepresentation() {}

	public Long getId() {
		return id;
	}
	public void setId(Long id) {
		this.id = id;
	}
	public String getUsername() {
		return username;
	}
	public void setUsername(String username) {
		this.username = username;
	}
	public Float getCreditLimit() {
		return creditLimit;
	}
	public void setCreditLimit(Float creditLimit) {
		this.creditLimit = creditLimit;
	}
	public String getPassword() {
		return password;
	}
	public void setPassword(String password) {
		this.password = password;
	}
	public String getRepeatPassword() {
		return repeatPassword;
	}
	public void setRepeatPassword(String repeatPassword) {
		this.repeatPassword = repeatPassword;
	}
	public String getFirstname() {
		return firstname;
	}
	public void setFirstname(String firstname) {
		this.firstname = firstname;
	}
	public String getLastname() {
		return lastname;
	}
	public void setLastname(String lastname) {
		this.lastname = lastname;
	}
	public UserState getState() {
		return state;
	}
	public void setState(UserState state) {
		this.state = state;
	}
	public String getAuthorities() {
		return authorities;
	}

	public void setAuthorities(String authorities) {
		this.authorities = authorities;
	}

	public boolean isEnabled() {
		return enabled;
	}

	public void setEnabled(boolean enabled) {
		this.enabled = enabled;
	}

	@Override
	public String toString() {
		return "firstName: " + this.getFirstname() + " lastName: " + this.getLastname() + " email: " + this.getUsername() 
				+ " password: " + this.getPassword() + " enabled: " + this.isEnabled() + " authorities: " + this.getAuthorities()
				+ " id: " + this.getId();
	}

	@Override
	public boolean equals(Object that) {
		if (that == null) return false;
		UserRepresentation thatUser = (UserRepresentation) that;
		if (this.username.equals(thatUser.username)) {		
			return true;
		} else {
			return false;
		}
	}

}
