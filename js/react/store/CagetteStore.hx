package react.store;

import js.Promise;
import haxe.Json;
import react.ReactComponent;
import react.ReactMacro.jsx;
import mui.CagetteTheme;

import utils.HttpUtil;

import Common;
using Lambda;

typedef CagetteStoreProps = {
	var place:Int;
	var date:String;
};

typedef ProductFilters = {
	@:optional var category:Int;
	@:optional var subcategory:Int;
	@:optional var tags:Array<String>;
	@:optional var producteur:Bool;
};

typedef  CagetteStoreState = {
	var place:PlaceInfos;
	var orderByEndDates:Array<OrderByEndDate>;
	var categories:Array<CategoryInfo>;
	var products:Array<ProductInfo>;
	//var order:OrderSimple;
	var filter:ProductFilters;
};

@:enum
abstract ServerUrl(String) to String {
	var CategoryUrl = '/api/shop/categories';
	var ProductUrl = '/api/shop/products';
	var InitUrl = '/api/shop/init';
	var ViewUrl = '/place/view';
}

/*
	const styles = {
	searchField: {
		width: 200,
		padding: '0.5em',
	},
	cagNavCategories: {
		padding: 0,
		height: 100,
	},
	button:{
			size: 'small',
			textTransform: 'none',
			color: '#84BD55',
		},
	cagSearchInput: {
		borderRadius: 5,

		border:'1px solid #E5D3BF',
		padding: '10px 12px',
		width: 'calc(100%)',
		'&:focus': {
			borderColor: '#80bdff',
		},
	},
	}
 */
class CagetteStore extends react.ReactComponentOfPropsAndState<CagetteStoreProps, CagetteStoreState> {

	public function new() {
		super();
		state = {
			place: null,
			orderByEndDates: [],
			categories: [],
			filter: {},
			products:[],
		};
	}

	static function fetch(url:ServerUrl, ?method:HttpMethod = GET, ?params:Dynamic = null, ?accept:FetchFormat = PLAIN_TEXT,
			?contentType:String = JSON):Promise<Dynamic> {
		return HttpUtil.fetch(url, method, params, accept, contentType);
	}

//TODO CLEAN
	public static var ALL_CATEGORY = {id:0, name:"Tous les produits"};
	public static var DEFAULT_CATEGORY = {id:-1, name:"Autres"};

	override function componentDidMount() {
		var initRequest = fetch(InitUrl, GET, {date: props.date, place: props.place}, JSON);
		initRequest.then(function(infos:Dynamic) {
			setState({
				place: infos.place,
				orderByEndDates: infos.orderEndDates
			});
		}).catchError(function(error) {
			trace("ERROR", error);
		});

		var categoriesRequest = fetch(CategoryUrl, GET, {date: props.date, place: props.place}, JSON);
		categoriesRequest.then(function(results:Dynamic) {
			var categories:Array<CategoryInfo> = results.categories;

			var subCategories = [];
			for (category in categories) {
				subCategories = subCategories.concat(category.subcategories);
			}

			setState({
				categories: categories,
			});

			var promises = [];
			subCategories.map(function(subcategory:CategoryInfo) {
				promises.push(fetch(ProductUrl, GET, {date: props.date, place: props.place, subcategory: subcategory.id}, JSON));
			});

			categories.unshift(DEFAULT_CATEGORY);
			categories.unshift(ALL_CATEGORY);

			js.Promise.all(promises).then(function(results:Array<Dynamic>) {
				var products = [];
				//trace("results ", results.length);
				// primises.all respect the order
				for (i in 0...results.length) {
					var result = results[i];
					var category = subCategories[i];
					//trace('Category $category contains ${result.products.length} produits');
					// transform results
					var catProducts:Array<ProductInfo> = Lambda.array(Lambda.map(result.products, function(p:Dynamic) {
						if( p.categories == null || p.categories.length == 0 ) {
							p.categories = [DEFAULT_CATEGORY];
							//trace("We assign a default category");
						} 
						return js.Object.assign({}, p, {unitType: Type.createEnumIndex(Unit, p.unitType)});
					}));
					//productsBySubcategoryIdMapCopy.set(category.id, products);
					products = products.concat(catProducts);
				}
				
				//trace('${products.length} produits trouvés ');
				setState({
					products:products,
					//productsBySubcategoryIdMap: productsBySubcategoryIdMapCopy
				}, function() {
					trace("products catalog updated");
				});
			});
		}).catchError(function(error) {
			trace("ERROR", error);
		});
	}


	function resetFilter() {
		setState({filter:{}});
	}

	function filterByCategory(categoryId:Int) {
		setState({ filter: {category:categoryId}});
	}

	function filterBySubCategory(categoryId:Int, subCategoryId:Int) {
		setState({ filter: {category:categoryId, subcategory:subCategoryId}});
	}

	function toggleFilterTag(tag:String) {
		var tags = state.filter.tags;
		if( tags == null ) tags = [];
		// toggle
		var hadTag = state.filter.tags.remove(tag);
		if( !hadTag ) state.filter.tags.push(tag);
		// assign
		var filter = js.Object.assign({}, state.filter, {tags:tags});
		setState({ filter: filter});
	}
	
	function submitOrder(order:OrderSimple) {
		var orderInSession = {
			total: order.total,
			products: order.products.map(function(p:ProductWithQuantity) {
				return {
					productId: p.product.id,
					quantity: p.quantity
				};
			})
		}
		trace('Order', orderInSession);
	}

	/**
	TODO : bloc de mise en avant.
	Par défaut ce sera les produits de la semaine. 
	Les conditions d'affichage sont encore à définir
	**/
	function renderPromo() {
		return null;
	}

	override public function render() {
		
		function filter(p, f:ProductFilters) {
			return FilterUtil.filterProducts(p, f.category, f.subcategory, f.tags, f.producteur);
		}

		return jsx('
			<div className="shop">
				${renderHeader()}
				<Categories 
					categories=${state.categories}
					resetFilter=${resetFilter}
					filterByCategory=${filterByCategory}
					filterBySubCategory=${filterBySubCategory}
					toggleFilterTag=${toggleFilterTag}
				/>

				{renderPromo()}
				<ProductList
					categories=${state.categories}
					products=${filter(state.products, state.filter)}
				/>
			</div>
		');
	}

	function renderHeader() {
		if (state.orderByEndDates == null || state.orderByEndDates.length == 0)
			return null;

		var endDates;
		// TODO Localization here
		if (state.orderByEndDates.length == 1) {
			var orderEndDate = state.orderByEndDates[0].date;
			endDates = [jsx('<div key=$orderEndDate>La commande fermera le $orderEndDate</div>')];
		} else {
			endDates = state.orderByEndDates.map(function(order) {
				if (order.contracts.length == 1) {
					return jsx('
						<div key=${order.date}>
							La commande ${order.contracts[0]} fermera le: ${order.date} 
						</div>
					');
				}

				return jsx('
					<div key=${order.date}>
						Les autres commandes fermeront: ${order.date} 
					</div>
				');
			});
		}

		// TODO Think about the way the place adress is built, why an array for zipCode and city ?
		// TODO LOCALIZATION
		var viewUrl = '$ViewUrl/${props.place}';
		var addressBlock = Lambda.array([
			state.place.address1,
			state.place.address2,
			[state.place.zipCode, state.place.city].join(" "),
		].mapi(function(index, element) {
			if (element == null)
				return null;
			return jsx('<div className="address" key=$index>$element</div>');
		}));

		return jsx('
			<Header submitOrder=$submitOrder />
		');
	}
}
