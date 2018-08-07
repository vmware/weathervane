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
/**
 * View Class for Updating Profile
 * 
 */
auction.views.UpdateProfile = Backbone.View.extend({

	/**
	 * Bind the events functions to the different HTML elements
	 */
	events : {
		'click #updateProfileBtn' : 'update',
		'blur #updateProfile-matchpasswd-input' : 'validatePassword'
	},

	initialize : function(options) {
		auction.containers.updateProfile = this.$el;
		this.model.on('sync', this.render, this);
	},

	/**
	 * Renders the Update profile view
	 */
	render : function() {

		this.$el.html(_
				.template(auction.utils.getTemplate(auction.conf.tpls.updateProfile))(
						this.model.attributes));

		// Cache all of the inputs
		this.firstnameInput = this.$('#updateProfile-firstname-input');
		this.lastnameInput = this.$('#updateProfile-lastname-input');
		this.emailInput = this.$('#updateProfile-email-input');
		this.creditLimitInput = this.$('#updateProfile-creditLimit-input');
		this.passwordInput = this.$('#updateProfile-password-input');
		this.matchpasswdInput = this.$('#updateProfile-matchpasswd-input');

		// Cache all of the controls
		this.firstnameControl = this.$('#updateProfile-firstname-control');
		this.lastnameControl = this.$('#updateProfile-lastname-control');
		this.emailControl = this.$('#updateProfile-email-control');
		this.creditLimitControl = this.$('#updateProfile-creditLimit-control');
		this.passwordControl = this.$('#updateProfile-password-control');
		this.matchpasswdControl = this.$('#updateProfile-matchpasswd-control');

		// General form error
		this.updateProfileError = this.$('#updateProfile-error');

		// Registration form fields errors
		this.matchpasswdError = this.$('#updateProfile-matchpasswd-error');
		this.emailError = this.$('#updateProfile-emailError');
		this.passwdError = this.$('#updateProfile-passwdError');
		this.creditLimitError = this.$('#updateProfile-creditLimitError');
		this.$el.show();
	},

	/**
	 * Validates that the password and retype password match
	 * 
	 * @return boolean
	 */
	validatePassword : function(event) {
		if (this.matchpasswdInput.val() != this.passwordInput.val()) {
			this.matchpasswdError.removeClass('hide');
			this.matchpasswdControl.addClass('has-error');
		} else {
			this.matchpasswdError.addClass('hide');
			this.matchpasswdControl.removeClass('has-error');
		}
	},

	update : function(event) {

		// Remove the error class from the inputs
		this.matchpasswdControl.removeClass('has-error');
		this.firstnameControl.removeClass('has-error');
		this.lastnameControl.removeClass('has-error');
		this.emailControl.removeClass('has-error');
		this.passwordControl.removeClass('has-error');
		this.creditLimitControl.removeClass('has-error');

		// Hide the updateProfile form errors
		this.matchpasswdError.addClass('hide');
		this.emailError.addClass('hide');
		this.passwdError.addClass('hide');
		this.creditLimitError.addClass('hide');
		// General form error
		this.updateProfileError.addClass('hide');

		event.preventDefault();

		var firstname = this.firstnameInput.val();
		var lastname = this.lastnameInput.val();
		var username = this.emailInput.val();
		var password = this.passwordInput.val();
		var repeatPassword = this.matchpasswdInput.val();
		var creditLimit = this.creditLimitInput.val();
		var view = this;

		// Update callbacks
		var callbacks = {
			success : function(model) {
				auction.instances.router.navigate(
						auction.conf.hash.userProfile, true);
			},
			error : function(model, error) {
				if (error.status === 409) {
					view.emailError.removeClass('hide');
					view.emailControl.addClass('has-error');
				}
			}
		};

		if (password == repeatPassword) {
			// Save the new account profile
			this.model.save({
				firstname : firstname,
				lastname : lastname,
				username : username,
				password : password,
				repeatPassword : repeatPassword,
				creditLimit : creditLimit
			}, callbacks);
		} else {
			view.matchpasswdError.removeClass('hide');
			view.matchpasswdControl.addClass('has-error');
		}

	}
});