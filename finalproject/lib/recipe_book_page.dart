import 'package:flutter/material.dart';
import 'add_recipe_page.dart';
import 'recipe_description_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_page.dart';

class RecipeBookPage extends StatefulWidget {
  const RecipeBookPage({super.key});

  @override
  RecipeBookPageState createState() => RecipeBookPageState();
}

class RecipeBookPageState extends State<RecipeBookPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> recipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  final TextEditingController searchController = TextEditingController();
  final List<String> mealTypes = [
    'All',
    'Breakfast',
    'Brunch',
    'Lunch',
    'Dinner',
    'Dessert'
  ];
  String selectedMealType = 'All';
  bool showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_searchRecipe);
    _fetchRecipes();
  }

  @override
  void dispose() {
    searchController.removeListener(_searchRecipe);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecipes() async {
    try {
      final snapshot = await _firestore.collection('recipes').get();
      final List<Map<String, dynamic>> fetchedRecipes =
          snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Store document ID for future updates/deletes
        return data;
      }).toList();
      setState(() {
        recipes = fetchedRecipes;
        filteredRecipes = recipes;
      });
    } catch (e) {
      print('Error fetching recipes: $e');
    }
  }

  Future<void> _addRecipe(Map<String, dynamic> newRecipe) async {
    try {
      final docRef = await _firestore.collection('recipes').add(newRecipe);
      newRecipe['id'] = docRef.id;
      setState(() {
        recipes.add(newRecipe);
        _searchRecipe();
      });
    } catch (e) {
      print('Error adding recipe: $e');
    }
  }

  void _searchRecipe() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredRecipes = recipes.where((recipe) {
        final recipeName = recipe['name'].toLowerCase();
        final matchesQuery = recipeName.contains(query);
        final matchesMealType = selectedMealType == 'All' ||
            (recipe['mealTypes'] as List).contains(selectedMealType);
        final matchesFavorite =
            !showOnlyFavorites || (recipe['favorite'] ?? false);
        return matchesQuery && matchesMealType && matchesFavorite;
      }).toList();
    });
  }

  void _filterByMealType(String? mealType) {
    setState(() {
      selectedMealType = mealType!;
      _searchRecipe();
    });
  }

  void _toggleFavoriteFilter() {
    setState(() {
      showOnlyFavorites = !showOnlyFavorites;
      _searchRecipe();
    });
  }

  void navigateToAddRecipe() async {
    final newRecipe = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const AddRecipePage()),
    );
    if (newRecipe != null) {
      _addRecipe(newRecipe);
    }
  }

  void navigateToRecipeDescription(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDescriptionPage(
          recipe: recipe,
          onUpdateRecipe: (updatedRecipe) async {
            await _firestore
                .collection('recipes')
                .doc(updatedRecipe['id'])
                .set(updatedRecipe);
            setState(() {
              final index = recipes.indexWhere((r) => r['id'] == recipe['id']);
              if (index != -1) {
                recipes[index] = updatedRecipe;
                _searchRecipe();
              }
            });
          },
          onDeleteRecipe: () async {
            await _firestore.collection('recipes').doc(recipe['id']).delete();
            setState(() {
              recipes.removeWhere((r) => r['id'] == recipe['id']);
              _searchRecipe();
            });
          },
        ),
      ),
    );
  }

  int checkcount = 0;

  void scheduleAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text(
          "Would you like to schedule weekly notifications to try a new recipe?",
          style: TextStyle(fontFamily: 'Lora'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // notif not set
              checkcount = 2;
              Navigator.pop(context);
            },
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              PermissionHandler.enableWeekly();
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  content: const Text(
                    "Weekly Notifications Scheduled.",
                    style: TextStyle(fontFamily: 'Lora'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // weekly set
                        checkcount = 1;
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "OK",
                        style: TextStyle(fontFamily: 'Lora'),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              "Proceed",
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recipe Book',
          style: TextStyle(
            fontFamily: 'Teko',
            fontSize: 38,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: showOnlyFavorites ? const Color(0xfff485b1) : Colors.grey,
            ),
            onPressed: _toggleFavoriteFilter,
          ),
          IconButton(
              onPressed: () {
                if ((checkcount == 0 || checkcount == 2)) {
                  scheduleAlert();
                  checkcount = 1;
                } else if ((checkcount == 1)) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      content: const Text(
                        "Your weekly notification is already scheduled.",
                        style: TextStyle(
                          fontFamily: 'Lora',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(
                              fontFamily: 'Lora',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            checkcount = 0;
                            const snackBar = SnackBar(
                                content: Text("Disabled weekly notifications"));
                            PermissionHandler.disableWeekly();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          },
                          child: const Text(
                            "Disable",
                            style: TextStyle(
                              fontFamily: 'Lora',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.alarm_add)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelStyle: const TextStyle(fontFamily: 'Lora'),
                      hintStyle: const TextStyle(fontFamily: 'Lora'),
                      hintText: 'Search recipes...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedMealType,
                  items: mealTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: _filterByMealType,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16.0,
                  crossAxisSpacing: 16.0,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredRecipes.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap: navigateToAddRecipe,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add, size: 50),
                            SizedBox(height: 8),
                            Text(
                              "Add Recipe",
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final recipe = filteredRecipes[index - 1];
                    return GestureDetector(
                      onTap: () => navigateToRecipeDescription(recipe),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: recipe['image'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.network(
                                        recipe['image'],
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Center(
                                      child: Text(
                                        'No Image',
                                        style: TextStyle(
                                          fontFamily: 'Lora',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                recipe['name'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Lora',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
