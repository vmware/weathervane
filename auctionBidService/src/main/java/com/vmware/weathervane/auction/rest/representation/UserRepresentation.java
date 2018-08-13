/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.auction.rest.representation;

import java.io.Serializable;

import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.User.UserState;

public class UserRepresentation extends Representation  implements Serializable{

	private static final long serialVersionUID = 1L;
	
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

	private UserRepresentation() {}
	
	/**
	 * This is a constructor creates a userRepresentation from a User. It uses the business
	 * rules to determine what the allowable next actions are based on the
	 * current state of the User. It then includes appropriate
	 * links for those actions in the representation.
	 * 
	 * @author hrosenbe
	 */
	public UserRepresentation(User theUser) {

		if (theUser == null) {
			this.setState(UserState.INCOMPLETE);
			return;
		}
		
		this.setId(theUser.getId());
		this.setUsername(theUser.getEmail());
		this.setFirstname(theUser.getFirstname());
		this.setLastname(theUser.getLastname());
		this.setCreditLimit(theUser.getCreditLimit());
		this.setPassword(null);
		this.setRepeatPassword(null);
		this.setAuthorities(theUser.getAuthorities());
		this.setEnabled(theUser.isEnabled());
		/*
		 * ToDo: This is where the links should be returned. Right now am
		 * just returning a state.
		 */
		this.setState(theUser.getState());
		
	}

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
