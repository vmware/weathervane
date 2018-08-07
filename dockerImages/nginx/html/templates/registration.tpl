<div class="row">
        <div class="col-lg-9 columns">
            <form class="form-horizontal">
                <fieldset>
                    <h3><%= translate("registerUserName") %><p><small><%= translate("enterAccountDetails") %></small></p></h3>
                    <div id="registration-error" class="hide col-lg-8 alert alert-block alert-error fade in">
                        <a data-dismiss="alert" class="close">x</a>
                        <h4 class="alert-heading"></h4>
                        <p></p>
                    </div>
                    <div class="row">
						<div class="col-lg-6">
	                        <div id="firstname-control" class="form-group">
	                            <label for="firstname-input" class="col-lg-4 control-label"><%= translate("firstName") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="text" value="" id="firstname-input" class="form-control pull-right focused"><br/>
	                                <span id="firstnameError" class="help-inline hide"><%= translate("firstnameError") %></span>
	                            </div>
	                        </div>
	                        <div id="lastname-control" class="form-group">
	                            <label for="lastname-input" class="col-lg-4 control-label"><%= translate("lastName") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="text" value="" id="lastname-input" class="form-control pull-right focused"><br/>
	                                <span id="lastnameError" class="help-inline hide"><%= translate("lastnameError") %></span>
	                            </div>
	                        </div>
	                        <div id="email-control" class="form-group">
	                            <label for="email-input" class="col-lg-4 control-label"><%= translate("email") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="email" value="" id="email-input" class="form-control pull-right focused"><br/>
	                                <span id="emailError" class="help-inline hide"><%= translate("emailError") %></span>
	                            </div>
	                        </div>
	                        <div id="creditLimit-control" class="form-group">
	                            <label for="creditLimit-input" class="col-lg-4 control-label"><%= translate("creditLimit") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="number" value="" id="creditLimit-input" class="form-control pull-right focused"><br/>
	                                <span id="creditLimitError" class="help-inline hide"><%= translate("creditLimitError") %></span>
	                            </div>
	                        </div>
	                    </div>
	                    <div class="col-lg-6">
	                        <div id="password-control" class="form-group">
	                            <label for="reg-password-input" class="col-lg-4 control-label"><%= translate("password") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="password" value="" id="reg-password-input" class="form-control pull-right focused"><br/>
	                                <span id="passwdError" class="help-inline hide"><%= translate("passwdError") %></span>
	                            </div>
	                        </div>
	                        <div id="matchpasswd-control" class="form-group">
	                            <label for="matchpasswd-input" class="col-lg-4 control-label"><%= translate("passwordConfirmation") %>:</label>
	                            <div class="col-lg-8">
	                                <input type="password" id="matchpasswd-input" class="form-control pull-right focused"><br/>
	                                <span id="matchpasswd-error" class="help-inline hide"><%= translate("passwordMatching") %></span>
	                            </div>
	                        </div>
	                    </div>
					</div>
					<div class="row">
                    	<div class="form-actions offset4 col-lg-4">
	                        <button id="registrationBtn" class="btn green-btn"><%= translate("register") %></button>
	                    </div>
					</div>
                </fieldset>
            </form>
        </div>
        <div class="col-lg-2">
            <h3><%= translate("auctionLogin") %></h3>
            <p><%= translate("alreadyRegistered") %></p>
            <p><a id="showLoginBtn"><%= translate("visitLoginPage") %></a></p>
        </div>
    </div>
</div>
