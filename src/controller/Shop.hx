package controller;
import Common;
import tools.ArrayTool;
import service.OrderService;

class Shop extends Controller
{
	
	var distribs : List<db.Distribution>;
	var contracts : List<db.Contract>;

	@tpl('shop/default.mtt')
	public function doDefault(place:db.Place,date:Date) {
		var products = getProducts(place,date);
		view.products = products;
		view.place = place;
		view.date = date;
		view.group = place.amap;		
		view.infos = ArrayTool.groupByDate(Lambda.array(distribs), "orderEndDate");

		//message if phone is required
		if(app.user!=null && app.user.amap.flags.has(db.Amap.AmapFlags.PhoneRequired) && app.user.phone==null){
			app.session.addMessage(t._("Members of this group should provide a phone number. <a href='/account/edit'>Please click here to update your account</a>."),true);
		}

		//event for additionnal blocks on home page
		var e = Blocks([], "shop");
		app.event(e);
		view.blocks = e.getParameters()[0];
	}
	
	/**
	 * prints the full product list and current cart in JSON
	 */
	public function doInit(place:db.Place,date:Date) {
		
		//init order serverside if needed		
		var order :OrderInSession = app.session.data.order; 
		if ( order == null) {
			app.session.data.order = order = cast {products:[]};
		}
		
		var products = [];
		var categs = new Array<{name:String,pinned:Bool,categs:Array<CategoryInfo>}>();		
		
		if (place.amap.flags.has(db.Amap.AmapFlags.ShopCategoriesFromTaxonomy)){
			
			//TAXO CATEGORIES
			products = getProducts(place, date, true);
		}else{
			
			//CUSTOM CATEGORIES
			products = getProducts(place, date, false);
		}
		
		categs = place.amap.getCategoryGroups();

		//clean 
		for ( p in order.products){
			p.product = null;
		}
		Sys.print( haxe.Serializer.run( {products:products,categories:categs,order:order} ) );
	}
	
	
	
	/**
	 * Get the available products list
	 */
	private function getProducts(place,date,?categsFromTaxo=false):Array<ProductInfo> {

		contracts = db.Contract.getActiveContracts(app.getCurrentGroup());
	
		for (c in Lambda.array(contracts)) {
			//only varying orders
			if (c.type != db.Contract.TYPE_VARORDER) {
				contracts.remove(c);
			}
			
			if (!c.isVisibleInShop()) {
				contracts.remove(c);
			}
			
		}

		view.contracts = contracts;
		
		var now = Date.now();
		var cids = Lambda.map(contracts, function(c) return c.id);
		var d1 = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0);
		var d2 = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59);

		//distribs open to orders, and where distribDate is in the date given as parameter
		distribs = db.Distribution.manager.search(($contractId in cids) && $orderStartDate <= now && $orderEndDate >= now && $date > d1 && $end < d2 && $place == place, false);
		var products = [];
		for ( d in distribs){
			for (p in d.contract.getProducts(true)){
				products.push( p.infos(categsFromTaxo,null,d) );
			}
		}
		return products;

		/*var cids = Lambda.map(distribs, function(d) return d.contract.id);
		var products = db.Product.manager.search(($contractId in cids) && $active==true, { orderBy:name }, false);

		return Lambda.array(Lambda.map(products, function(p) return p.infos(categsFromTaxo)));*/
	}
	
	/**
	 * Overlay window loaded by Ajax for product Infos
	 */
	@tpl('shop/productInfo.mtt')
	public function doProductInfo(p:db.Product,?args:{distribution:db.Distribution}) {
		var d = args!=null && args.distribution!=null ? args.distribution : null;
		view.p = p.infos(null,null,d);
		view.product = p;
		view.vendor = p.contract.vendor;
	}
	
	/**
	 * receive cart
	 */
	public function doSubmit() {
		
		var order : OrderInSession = haxe.Json.parse(app.params.get("data"));
		app.session.data.order = order;
		
	}
	
	/**
	 * add a product to the cart
	 */
	public function doAdd(productId:Int, quantity:Int) {
	
		var order : OrderInSession =  app.session.data.order;
		if ( order == null) order = cast { products:[] };		
		order.products.push( { productId:productId, quantity:quantity } );		
		Sys.print( haxe.Json.stringify( {success:true} ) );
		
	}
	
	/**
	 * remove a product from cart 
	 */
	public function doRemove(pid:Int) {
	
		var order:OrderInSession =  app.session.data.order;
		if ( order == null) return;
		
		for ( p in order.products.copy()) {
			if (p.productId == pid) {
				order.products.remove(p);
			}
		}
		
		Sys.print( haxe.Json.stringify( { success:true } ) );		
	}
	
	
	/**
	 * validate the order
	 */
	@tpl('shop/needLogin.mtt')
	public function doValidate(place:db.Place, date:Date){
		
		//login is needed : display a loginbox
		if (app.user == null) {
			view.redirect = "/shop/validate/" + place.id + "/" + date.toString().substr(0, 10);
			view.group = place.amap;
			view.register = true;
			view.message =  t._("In order to confirm your order, You need to authenticate.");
			return;
		}
		
		//add the user to this group if needed
		if (place.amap.regOption == db.Amap.RegOption.Open && db.UserAmap.get(app.user, place.amap) == null){
			app.user.makeMemberOf(place.amap);			
		}

		var order : OrderInSession = app.session.data.order;
		if (order == null || order.products == null || order.products.length == 0) {
			throw Error("/", t._("Your order is empty") );
		}
		
		if (place == null) throw "place cannot be empty";
		if (date == null) throw "date cannot be empty";		

		var products = getProducts(place, date);

		var errors = [];
		order.total = 0.0;
		
		//cleaning
		for (o in order.products.copy()) {
			
			var p = db.Product.manager.get(o.productId, false);
			
			//check that the products are from this group (we never know...)
			if (p.contract.amap.id != app.user.amap.id){
				app.session.data.order = null;
				throw Error("/", t._("This cart is invalid") );
			}
			
			//check if the product is available
			if (Lambda.find(products, function(x) return x.id == o.productId) == null) {
				errors.push( t._("This distribution does not supply the product <b>::pname::</b>",{pname:p.name}) );
				order.products.remove(o);
				continue;
			}else{
				o.product = p;
			}

			//find distrib
			var d = Lambda.find(distribs, function(d) return d.contract.id == p.contract.id);
			if ( d == null ){
				errors.push( t._("This distribution does not supply the product <b>::pname::</b>",{pname:p.name}) );
				order.products.remove(o);
				continue;
			}else{
				o.distributionId = d.id;
			}
			
			//moderate order according available stocks
			if (p.stock != null && p.contract.hasStockManagement() ) {
				if (p.stock - o.quantity < 0) {
					var canceled = o.quantity - p.stock;
					o.quantity -= canceled;
					errors.push(t._("Order of ::pname:: reduced to ::oquantity:: to match remaining stock", {pname:p.name, oquantity:o.quantity}));
				}
			}
		
			order.total += p.getPrice() * o.quantity;
		}
		
		order.userId = app.user.id;
		
		if (errors.length > 0) {
			app.session.addMessage(errors.join("<br/>"), true);
		}
		
		//store cart in session
		app.session.data.order = order;		
		
		//debug
		for ( p in order.products){
			if (p.distributionId == null){
				App.current.logError(place.amap.name + " : panier sans distrib Id : " + Std.string(order) );
				break;
			}
		}
		
		if (app.user.amap.hasPayments()){			
			//Go to payments page
			throw Redirect("/transaction/pay/");
		}else{
			//no payments, confirm direclty
			OrderService.confirmSessionOrder(order);			
			throw Ok("/contract", t._("Your order has been confirmed") );	
		}

	}

	
}
