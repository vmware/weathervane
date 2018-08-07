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
auction.views.Registration = Backbone.View
		.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click #registrationBtn' : 'registration',
				'click #showLoginBtn' : 'login',
				'keypress [type=number]' : 'validateNumber',
				'blur #matchpasswd-input' : 'validatePassword'
			},

			/**
			 * Class constructor
			 * 
			 * @param Object
			 *            options: - el: selector for the container
			 * @return void
			 */
			initialize : function(options) {
				auction.containers.registration = this.$el;
			},

			/**
			 * Renders the Registration View
			 * 
			 * @param mixed
			 *            errorKey: Name of an error key from
			 *            auction.strings to be displayed. It can be null
			 *            (no error show on render)
			 * @return void
			 */
			render : function(errorKey) {

				if (!this.$el.html()) {
					this.$el
							.html(_
									.template(
											auction.utils
													.getTemplate(auction.conf.tpls.registration))
									());

					if (errorKey) {
						var registrationError = this.$('#registration-error');
						registrationError.find('p').html(translate(errorKey));
						registrationError.removeClass('hide');
					}

					// Cache all of the inputs
					this.firstnameInput = this.$('#firstname-input');
					this.lastnameInput = this.$('#lastname-input');
					this.emailInput = this.$('#email-input');
					this.creditLimitInput = this.$('#creditLimit-input');
					this.passwordInput = this.$('#reg-password-input');
					this.matchpasswdInput = this.$('#matchpasswd-input');

					// Cache all of the controls
					this.firstnameControl = this.$('#firstname-control');
					this.lastnameControl = this.$('#lastname-control');
					this.emailControl = this.$('#email-control');
					this.creditLimitControl = this.$('#creditLimit-control');
					this.passwordControl = this.$('#reg-password-control');
					this.matchpasswdControl = this.$('#matchpasswd-control');

					// General form error
					this.registrationError = this.$('#registration-error');

					// Registration form fields errors
					this.matchpasswdError = this.$('#matchpasswd-error');
					this.firstnameError = this.$('#firstnameError');
					this.lastnameError = this.$('#lastnameError');
					this.emailError = this.$('#emailError');
					this.passwdError = this.$('#passwdError');
					this.creditLimitError = this.$('#creditLimitError');
				}
				this.$el.show();
			},

			/**
			 * Validates that the input can only receive digits
			 * 
			 * @return boolean
			 */
			validateNumber : function(event) {
				return auction.utils.validateNumber(event);
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

			/**
			 * Registration event
			 * 
			 * @return void
			 */
			registration : function(event) {

				// Remove the error class from the inputs
				this.matchpasswdControl.removeClass('has-error');
				this.firstnameControl.removeClass('has-error');
				this.lastnameControl.removeClass('has-error');
				this.emailControl.removeClass('has-error');
				this.passwordControl.removeClass('has-error');
				this.creditLimitControl.removeClass('has-error');

				// Hide the registration form erros
				this.matchpasswdError.addClass('hide');
				this.firstnameError.addClass('hide');
				this.lastnameError.addClass('hide');
				this.emailError.addClass('hide');
				this.passwdError.addClass('hide');
				this.creditLimitError.addClass('hide');
				// General form error
				this.registrationError.addClass('hide');

				event.preventDefault();

				var firstname = this.firstnameInput.val();
				var lastname = this.lastnameInput.val();
				var username = this.emailInput.val();
				var password = this.passwordInput.val();
				var repeatPassword = this.matchpasswdInput.val();
				var creditLimit = this.creditLimitInput.val();
				var view = this;

				var inputArray = [ username, firstname, lastname, creditLimit,
						password, repeatPassword ];
				var emptyField = false;

				for ( var i = 0, j = inputArray.length; i < j; i++) {
					if (inputArray[i] == '') {
						this.registrationError.find('p').html(
								translate('emptyFieldError'));
						this.registrationError.removeClass('hide');
						emptyField = true;
						break
					}
				}

				// Set the Account Profile model
				this.model = new auction.models.User();

				// Registration callbacks
				var callbacks = {
					success : function() {
						auction.utils.login(username, password, {
							success : function(jqXHR, textStatus) {
								// Clear the credentials from the inputs
								view.firstnameInput.val('');
								view.lastnameInput.val('');
								view.emailInput.val('');
								view.passwordInput.val('');
								view.matchpasswdInput.val('');
								view.creditLimitInput.val('');

								// Show the loading page and render the
								// dashboard
								auction.instances.router.navigate(
										auction.conf.hash.attendAuctions, true);
							},
							error : function(jqXHR, textStatus, errorThrown) {
								switch (jqXHR.status) {
								case 401:
									alert(translate('invalidUser'));
									break;
								default:
									alert(translate('unknownError'));
									break;
								}
							}
						});
					},
					error : function(model, error) {
						errorsStr = translate('unknownError');
						if (_.isArray(error)) {
							errorsStr = '';
							for ( var x in error) {
								errorsStr += translate(error[x]) + '<br>';
								switch (error[x]) {
								case 'firstnameError':
									view.firstnameError.removeClass('hide');
									view.firstnameControl.addClass('has-error');
									break;
								case 'lastnameError':
									view.lastnameError.removeClass('hide');
									view.lastnameControl.addClass('has-error');
									break;
								case 'emailError':
									view.emailError.removeClass('hide');
									view.emailControl.addClass('has-error');
									break;
								case 'passwdError':
									view.passwdError.removeClass('hide');
									view.passwdControl.addClass('has-error');
									break;
								case 'creditLimitError':
									view.creditLimitError.removeClass('hide');
									view.creditLimitControl.addClass('has-error');
									break;
								}
							}
						} else if (error.responseText) {
							errorsStr = error.responseText;
						}
						view.registrationError.find('h4.alert-heading').html(
								translate('anError'));
						view.registrationError.find('p').html(errorsStr);
						view.registrationError.removeClass('hide');
					}
				};

				if (emptyField == false) {
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
			}
		});