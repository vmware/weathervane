<div class="title"><h4><%= translate("itemDetail") %></h4></div>
<div class="row">
	<div class="col-lg-8">
		<table class="table">
			<tbody id="itemDetailTable1">
				<tr>
					<td><%= translate("itemId") %></td>
					<td><%= id %></td>
				</tr>
				<tr>
					<td><%= translate("itemName") %></td>
					<td><%= name %></td>
				</tr>
				<tr>
					<td><%= translate("condition") %></td>
					<td><%= condition %></td>
				</tr>
				<tr>
					<td><%= translate("dateOfOrigin") %></td>
					<td><%= dateOfOrigin %></td>
				</tr>
				<tr>
					<td><%= translate("description") %></td>
					<td><%= longDescription %></td>
				</tr>
				<tr>
					<td><%= translate("itemState") %></td>
					<td><%= state %></td>
				</tr>
				<tr>
					<td><%= translate("startingBid") %></td>
					<td><%= auction.utils.printCurrency(startingBidAmount) %></td>
				</tr>
				<tr>
					<td><%= translate("purchaseDate") %></td>
					<td><%= purchaseDate %></td>
				</tr>
				<tr>
					<td><%= translate("purchasePrice") %></td>
					<td><%= auction.utils.printCurrency(purchasePrice) %></td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="itemDetailImages col-lg-4"></div>
</div>

