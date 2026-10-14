import '../vegetable_database.dart';
import 'vegetables_flower_fruit_catalog.dart';
import 'vegetables_root_leaf_catalog.dart';

export 'vegetables_flower_fruit_catalog.dart';
export 'vegetables_root_leaf_catalog.dart';

/// Combined kitchen vegetable catalog aggregating root, leaf, flower, and fruit
/// vegetables.
const List<VegetableEntry> vegetablesCatalog = [
  ...vegetablesRootLeafCatalog,
  ...vegetablesFlowerFruitCatalog,
];
