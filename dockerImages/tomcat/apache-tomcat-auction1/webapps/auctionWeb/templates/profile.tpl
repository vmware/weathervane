<div class="col-lg-9 columns">
    <form class="form-horizontal">
        <fieldset>
            <h3><%= translate("accountProfile") %></h3>
            <div id="update-successful" class="columns sidebar hide fade in"> </div>
            <div id="update-error" class="hide col-lg-8 alert alert-block alert-error fade in">
                <a data-dismiss="alert" class="close">x</a>
                <h4 class="alert-heading"></h4>
                <p></p>
            </div>
            <div class="row">
				<div class="col-lg-4">
	                <div id="fullname-control" class="control-group">
	                    <label for="fullname-input" class="control-label"><%= translate("fullName") %>:</label>
	                    <div class="controls">
	                        <input type="text" value="<%= fullname %>" id="fullname-input" class="col-lg-4 focused" maxlength="100"><br/>
	                        <span id="fullnameError" class="help-inline hide"><%= translate("fullnameError") %></span>
	                    </div>
	                </div>
	                <div id="username-control" class="control-group">
	                    <label for="username-input" class="control-label"><%= translate("username") %>:</label>
	                    <div class="controls">
	                        <input type="text" value="<%= userid %>" id="username-input" class="col-lg-4 focused" maxlength="100"><br/>
	                        <span id="usernameError" class="help-inline hide"><%= translate("usernameError") %></span>
	                    </div>
	                </div>
	                <div id="password-control" class="control-group">
	                    <label for="password-input" class="control-label"><%= translate("newPassword") %>:</label>
	                    <div class="controls">
	                        <input type="password" value="<%=passwd %>" id="password-input" class="col-lg-4 focused" maxlength="20"><br/>
	                        <span id="passwdError" class="help-inline hide"><%= translate("passwdError") %></span>  
	                    </div>
	                </div>
	                <div id="matchpasswd-control" class="control-group">
	                    <label for="matchpasswd-input" class="control-label"><%= translate("passwordConfirmation") %>:</label>
	                    <div class="controls">
	                        <input type="password" value="<%=passwd %>" id="matchpasswd-input" class="col-lg-4 focused" maxlength="20"><br/>
	                        <span id="matchpasswd-error" class="help-inline hide"><%= translate("passwordMatching") %></span>
	                    </div>
	                </div>
	            </div>
	            <div class="col-lg-4">
	                <div id="email-control" class="control-group">
	                    <label for="email-input" class="control-label"><%= translate("email") %>:</label>
	                    <div class="controls">
	                        <input type="text" value="<%= email %>" id="email-input" class="col-lg-4 focused" maxlength="100"><br/>
	                        <span id="emailError" class="help-inline hide"><%= translate("emailError") %></span>
	                    </div>
	                </div>
	                <div id="creditcard-control" class="control-group">
	                    <label for="creditcard-input" class="control-label"><%= translate("creditCardNumber") %>:</label>
	                    <div class="controls">
	                        <input type="text" value="<%= creditcard %>" id="creditcard-input" class="col-lg-4 focused" maxlength="16"><br/>
	                        <span id="creditcardError" class="help-inline hide"><%= translate("creditcardError") %></span>
	                    </div>
	                </div>
	                <div id="address-control" class="control-group">
	                    <label for="address-input" class="control-label"><%= translate("address") %>:</label>
	                    <div class="controls">
	                        <textarea rows="3" id="address-input" class="col-lg-4" maxlength="250"><%= address %></textarea><br/>
	                        <span id="addressError" class="help-inline hide"><%= translate("addressError") %></span>
	                    </div>
	                </div>
	            </div>
			</div>
            <div class="row">
				<div class="form-actions offset4 col-lg-4 ">
	                <button id="updateBtn" class="btn green-btn"><%= translate("update") %></button>
	            </div>
			</div>
        </fieldset>
    </form>
    <!--<p><img src="custom/images/bg-corner.png" alt="" class="corner" /></p>-->
</div>
