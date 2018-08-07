<div class="title"><h4><%= translate("accountProfile") %></h4></div>
<div class="row">
	<div class="col-lg-6">
		<table class="table">
			<tbody id="accountProfileTable1">
				<tr>
					<td><%= translate("username") %></td>
					<td><%= username %></td>
				</tr>
				<tr>
					<td><%= translate("firstName") %></td>
					<td><%= firstname %></td>
				</tr>
				<tr>
					<td><%= translate("lastName") %></td>
					<td><%= lastname %></td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="col-lg-6">
		<table class="table">
			<tbody id="accountProfileTable2">
				<tr>
					<td><%= translate("creditLimit") %></td>
					<td><%= creditLimit %></td>
				</tr>
				<tr>
					<td><%= translate("userState") %></td>
					<td><%= state %></td>
				</tr>
				<tr>
					<td><%= translate("authorities") %></td>
					<td><%= authorities %></td>
				</tr>
			</tbody>
		</table>
	</div>
</div>
