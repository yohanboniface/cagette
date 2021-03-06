package test;
import Common;
/**
 * CAGETTE.NET TEST SUITE
 * @author fbarbut
 */
class TestSuite
{

	static function main() {
		
		connectDb();
		var r = new haxe.unit.TestRunner();

		//Cagette core tests
		r.add(new test.TestUser());
		r.add(new test.TestOrders());		
		r.add(new test.TestTools());
		r.add(new test.TestDistributions());
		r.add(new test.TestPayments());
		r.add(new test.TestReports());

		#if plugins
		//Cagette-pro tests, keep in this order
		r.add(new pro.test.TestProductService());
		r.add(new pro.test.TestRemoteCatalog());
		r.add(new pro.test.TestDistribService());
		r.add(new pro.test.TestReports());
		//wholesale-order tests
		r.add(new who.test.TestWho());
		#end

		r.run();
	}

	static function connectDb() {
		var dbstr = Sys.args()[0];
		var dbreg = ~/([^:]+):\/\/([^:]+):([^@]*?)@([^:]+)(:[0-9]+)?\/(.*?)$/;
		if( !dbreg.match(dbstr) )
			throw "Configuration requires a valid database attribute, format is : mysql://user:password@host:port/dbname";
		var port = dbreg.matched(5);
		var dbparams = {
			user:dbreg.matched(2),
			pass:dbreg.matched(3),
			host:dbreg.matched(4),
			port:port == null ? 3306 : Std.parseInt(port.substr(1)),
			database:dbreg.matched(6),
			socket:null
		};
		
		sys.db.Manager.cnx = sys.db.Mysql.connect(dbparams);
		sys.db.Manager.initialize();
	}
	
	
	public static function initDB(){
		//NUKE EVERYTHING BWAAAAH !!
		sys.db.Manager.cleanup(); //cleanup cache objects
		sql("DROP DATABASE tests;");
		sql("CREATE DATABASE tests;");
		sql("USE tests;");

		var tables : Array<Dynamic> = [
			
			//cagette
			db.TxpProduct.manager,
			db.TxpCategory.manager,
			db.TxpSubCategory.manager,
			db.Category.manager,
			db.CategoryGroup.manager,
			db.ProductCategory.manager,

			db.Basket.manager,
			db.UserContract.manager,
			db.UserAmap.manager,
			db.Operation.manager,

			db.User.manager,
			db.Amap.manager,
			db.Contract.manager,
			db.Product.manager,
			db.Vendor.manager,
			db.Place.manager,
			db.Distribution.manager,
			db.DistributionCycle.manager,						
			
			//sugoi tables
			sugoi.db.Cache.manager,
			sugoi.db.Error.manager,
			sugoi.db.File.manager,
			sugoi.db.Session.manager,
			sugoi.db.Variable.manager,
		];
	
		for(t in tables) createTable(t);

		#if plugins
		//add Cpro datas : we need those tables even in cagette core tests
		pro.test.ProTestSuite.initDB();
		pro.test.ProTestSuite.initDatas();
		#end
	}
	
	public static function createTable( m  ){
		if ( sys.db.TableCreate.exists(m) ){
			drop(m);
		}
		// Sys.println("Creating table "+ m.dbInfos().name);
		sys.db.TableCreate.create(m);		
	}

	public static function truncate(m){
		sql("TRUNCATE TABLE "+m.dbInfos().name+";");
	}

	public static function drop(m){
		sql("DROP TABLE "+m.dbInfos().name+";");			
	}

	public static function sql(sql){
		return sys.db.Manager.cnx.request(sql);
	}
	
	//shortcut to datas
	public static var FRANCOIS:db.User = null; 
	public static var SEB:db.User = null; 
	public static var JULIE:db.User = null; 

	public static var CHICKEN:db.Product = null; 
	public static var STRAWBERRIES:db.Product = null; 
	public static var APPLES:db.Product = null; 
	public static var AMAP_DU_JARDIN:db.Amap = null;
	public static var LOCAVORES:db.Amap = null;
	public static var PANIER_AMAP_LEGUMES:db.Product = null;
	public static var DISTRIB_CONTRAT_AMAP:db.Distribution = null;
	public static var DISTRIB_FRUITS_PLACE_DU_VILLAGE:db.Distribution = null;
	public static var DISTRIB_LEGUMES_RUE_SAUCISSE:db.Distribution = null;
	public static var CONTRAT_LEGUMES:db.Contract = null;
	public static var PLACE_DU_VILLAGE:db.Place = null;	
	public static var COURGETTES:db.Product = null;
	public static var CARROTS:db.Product = null;
	public static var FLAN:db.Product = null;
	public static var CROISSANT:db.Product = null;
	public static var DISTRIB_PATISSERIES:db.Distribution = null;
	
	public static function initDatas(){

		//USERS
		
		var f = new db.User();
		f.firstName = "François";
		f.lastName = "B";
		f.email = "francois@alilo.fr";
		f.insert();

		FRANCOIS = f;
		
		var u = new db.User();
		u.firstName = "Seb";
		u.lastName = "Z";
		u.email = "sebastien@alilo.fr";
		u.insert();		

		SEB = u;

		var u = new db.User();
		u.firstName = "Julie";
		u.lastName = "B";
		u.email = "julie@alilo.fr";
		u.insert();		

		JULIE = u;
		
		initApp(u);
		
		//GROUP "AMAP du Jardin public"
		var a = new db.Amap();
		a.name = "AMAP du Jardin public";
		a.contact = f;
		a.flags.set(db.Amap.AmapFlags.HasPayments);
		a.insert();
		AMAP_DU_JARDIN = a;
		
		var place = new db.Place();
		place.name = "Place du village";
		place.zipCode = "00000";
		place.city = "St Martin";
		place.amap = a;
		place.insert();

		PLACE_DU_VILLAGE = place;
		
		//VENDOR "Ferme de la galinette"
		var v = new db.Vendor();
		v.name = "La ferme de la Galinette";
		v.email = "galinette@gmail.com";
		v.zipCode = "00000";
		v.city = "Bourligheim";
		v.insert();
		
		var c = new db.Contract();
		c.name = "Contrat AMAP Légumes";
		c.startDate = new Date(2017, 1, 1, 0, 0, 0);
		c.endDate = new Date(2030, 12, 31, 23, 59, 0);
		c.vendor = v;
		c.amap = a;
		c.type = db.Contract.TYPE_CONSTORDERS;
		c.insert();
		
		var p = new db.Product();
		p.name = "Panier Légumes";
		p.price = 13;
		p.contract = c;
		p.insert();

		PANIER_AMAP_LEGUMES = p;

		var d = new db.Distribution();
		d.date = new Date(2017, 5, 1, 19, 0, 0);
		d.end = new Date(2017, 5, 1, 20, 0, 0);
		d.orderStartDate = new Date(2017, 4, 1, 20, 0, 0);
		d.orderEndDate = new Date(2017, 4, 30, 20, 0, 0);
		d.contract = c;
		d.place = place;
		d.insert();

		DISTRIB_CONTRAT_AMAP = d;
		
		//varying contract for strawberries with stock mgmt
		var c = new db.Contract();
		c.name = "Commande fruits";
		c.vendor = v;
		c.startDate = new Date(2017, 1, 1, 0, 0, 0);
		c.endDate = new Date(2030, 12, 31, 23, 59, 0);
		c.flags.set(db.Contract.ContractFlags.StockManagement);
		c.type = db.Contract.TYPE_VARORDER;
		c.amap = a;
		c.insert();
		
		var p = new db.Product();
		p.name = "Fraises";
		p.qt = 1;
		p.unitType = Common.Unit.Kilogram;
		p.price = 10;
		p.organic = true;
		p.contract = c;
		p.stock = 8;
		p.insert();
		
		STRAWBERRIES = p;
		
		var p = new db.Product();
		p.name = "Pommes";
		p.qt = 1;
		p.unitType = Common.Unit.Kilogram;
		p.price = 6;
		p.organic = true;
		p.contract = c;
		p.stock = 12;
		p.insert();
		
		APPLES = p;

		var d = new db.Distribution();
		d.date = new Date(2017, 5, 1, 19, 0, 0);
		d.end = new Date(2017, 5, 1, 20, 0, 0);
		d.orderStartDate = new Date(2017, 4, 1, 20, 0, 0);
		d.orderEndDate = new Date(2017, 4, 30, 20, 0, 0);
		d.contract = c;
		d.place = place;
		d.insert();

		DISTRIB_FRUITS_PLACE_DU_VILLAGE = d;
		
		//second group 
		var a = new db.Amap();
		a.name = "Les Locavores de la Rue Saucisse";
		a.contact = f;
		a.flags.set(db.Amap.AmapFlags.HasPayments);
		a.insert();
		LOCAVORES = a;
		
		var place = new db.Place();
		place.name = "Rue Saucisse";
		place.zipCode = "00000";
		place.city = "St Martin";
		place.amap = a;
		place.insert();
		
		var v = new db.Vendor();
		v.name = "La ferme de la courgette enragée";
		v.email = "courgette@gmail.com";
		v.zipCode = "00000";
		v.city = "Bourligeac";
		v.insert();
		
		var c = new db.Contract();
		c.name = "Commande Legumes";
		c.startDate = new Date(2017, 1, 1, 0, 0, 0);
		c.endDate = new Date(2030, 12, 31, 23, 59, 0);
		c.vendor = v;
		c.amap = a;
		c.type = db.Contract.TYPE_VARORDER;
		c.insert();
		
		CONTRAT_LEGUMES = c;

		var p = new db.Product();
		p.name = "Courgettes";
		p.qt = 1;
		p.unitType = Common.Unit.Kilogram;
		p.price = 3.5;
		p.vat = 5.5;
		p.organic = true;
		p.contract = c;
		p.insert();

		COURGETTES = p;
		
		var p = new db.Product();
		p.name = "Carottes";
		p.qt = 1;		
		p.unitType = Common.Unit.Kilogram;
		p.price = 2.8;
		p.vat = 5.5;
		p.contract = c;
		p.insert();
		
		CARROTS = p;

		var p = new db.Product();
		p.name = "Poulet";
		p.qt = 1.5;
		p.unitType = Common.Unit.Kilogram;
		p.price = 15;
		p.vat = 5.5;
		p.multiWeight = true;
		p.hasFloatQt = true;
		p.contract = c;
		p.insert();

		CHICKEN = p;
		
		var d = service.DistributionService.create(c,new Date(2017, 5, 1, 19, 0, 0),new Date(2017, 5, 1, 19, 2, 0),place.id,null,null,null,null,new Date(2017, 4, 10, 19, 0, 0),new Date(2017, 4, 20, 19, 0, 0));		
		DISTRIB_LEGUMES_RUE_SAUCISSE = d;

		//PASTRY

		var c = new db.Contract();
		c.name = "Commande Pâtisseries";
		c.startDate = new Date(2017, 1, 1, 0, 0, 0);
		c.endDate = new Date(2017, 12, 31, 23, 59, 0);
		c.vendor = v;
		c.amap = a;
		c.type = db.Contract.TYPE_VARORDER;
		c.insert();

		var p = new db.Product();
		p.name = "Flan";
		p.qt = 1;
		p.unitType = Common.Unit.Kilogram;
		p.price = 3.5;
		p.organic = true;
		p.contract = c;
		p.insert();

		FLAN = p;
		
		var p = new db.Product();
		p.name = "Croissant";
		p.qt = 1;
		p.unitType = Common.Unit.Kilogram;
		p.price = 2.8;
		p.contract = c;
		p.insert();

		CROISSANT = p;

		var d = new db.Distribution();
		d.date = new Date(2017, 5, 1, 19, 0, 0);
		d.contract = c;
		d.place = place;
		d.insert();

		DISTRIB_PATISSERIES = d;
	}
	
	static function initApp(u:db.User){
		
		//setup App
		var app = App.current = new App();
		App.config.DEBUG = true;
		app.initLang("en");

		app.eventDispatcher = new hxevents.Dispatcher<Event>();
		app.plugins = [];
		//internal plugins
		app.plugins.push(new plugin.Tutorial());
		
		//optionnal plugins
		#if plugins
		//app.plugins.push( new hosted.HostedPlugIn() );				
		app.plugins.push( new pro.ProPlugIn() );		
		app.plugins.push( new connector.ConnectorPlugIn() );				
		//app.plugins.push( new pro.LemonwayEC() );
		app.plugins.push( new who.WhoPlugIn() );
		#end
		
		App.current.user = u;
		App.current.view = new View();
	}
}

