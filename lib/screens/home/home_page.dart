import 'package:animations/animations.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:serene/blocs/blocs.dart';
import 'package:serene/blocs/result_state.dart';
import 'package:serene/blocs/sound_bloc.dart';
import 'package:serene/config/assets.dart';
import 'package:serene/config/constants.dart';
import 'package:serene/config/dimen.dart';
import 'package:serene/config/plurals.dart';
import 'package:serene/config/typography.dart';
import 'package:serene/model/category.dart';
import 'package:serene/model/sound.dart';
import 'package:serene/screens/details/category_details_page.dart';
import 'package:serene/screens/home/play_button.dart';
import 'package:serene/screens/home/playing_sound_view.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool isPlaying = false;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    BlocProvider.of<CategoryBloc>(context).add(FetchCategories());
    controller = AnimationController(
        duration: const Duration(milliseconds: Constants.animationDurationInMillis),
        vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          children: [
            Spacer(),
            Container(
              width: 60,
              height: 60,
              child: FlareActor(
                Assets.logoAnimation,
                alignment: Alignment.center,
                fit: BoxFit.contain,
                animation: "serene_logo",
              ),
            ),
            Text(
              "Serene",
              style: AppTypography.appTitle().copyWith(color: Colors.white),
            ),
            Spacer()
          ],
        ),
        elevation: 0,
      ),
      body:
      Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: Color(0xFF2C2C2C)),
          child: Stack(
            children: <Widget>[contentArea()],
          )),
    );
  }

  Widget contentArea() {
    BlocProvider.of<SoundBloc>(context).add(FetchPlayingSounds());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: Dimen.padding, right: Dimen.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Spacer(),
            showPlayButton(context),
            Spacer(),
            showCategories(),
          ],
        ),
      ),
    );
  }

  Widget showPlayButton(BuildContext context) {
    return BlocBuilder<SoundBloc, Result>(
      condition: (previousState, state) {
        if (previousState is Success && state is Success) {
          return previousState.value != state.value;
        }
        return previousState != state;
      },
      builder: (context, state) {
        int playingItems = 0;
        if (state is Success) {
          isPlaying = true;
          playingItems = (state.value as List<Sound>).length;
        } else {
          isPlaying = false;
          playingItems = 0;
        }

        isPlaying ? controller.forward() : controller.reverse();

        return PlayButton(
          isPlaying: isPlaying,
          playingCount: playingItems,
          onPlayAction: _onPlayButtonPressed,
          onPlaylistAction: () {
            _soundsPlayingModalBottomSheet(context);
          },
        );
      },
    );
  }

  Widget showCategories() {
    return BlocBuilder<CategoryBloc, Result>(condition: (previousState, state) {
      if (previousState == state &&
          previousState is Success &&
          state is Success) {
        return previousState.value == state.value;
      }
      return previousState != state;
    }, builder: (context, state) {
      if (state is Empty) {
        return Center(child: Text('No Categories Found'));
      }
      if (state is Loading) {
        return Center(child: CircularProgressIndicator());
      }
      if (state is Success) {
        return categoriesView(state.value);
      }
      if (state is Error) {
        return Center(child: Text('Error fetching categories'));
      }
      return Center(child: Text('No Categories Found'));
    });
  }

  Widget categoriesView(List<Category> categories) {
    List<StaggeredTile> _staggeredTiles = const <StaggeredTile>[
      const StaggeredTile.count(2, 2),
      const StaggeredTile.count(2, 2.5),
      const StaggeredTile.count(2, 2.5),
      const StaggeredTile.count(2, 2),
    ];

    return StaggeredGridView.countBuilder(
      crossAxisCount: 4,
      itemCount: 4,
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) =>
          categoryView(categories[index]),
      staggeredTileBuilder: (int index) => _staggeredTiles[index],
      mainAxisSpacing: Dimen.padding,
      crossAxisSpacing: Dimen.padding,
    );
  }

  Widget categoryView(Category category) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      openBuilder: (BuildContext context, VoidCallback _) {
        return CategoryDetailsPage(category: category);
      },
      closedColor: category.color,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(Dimen.cornerRadius),
        ),
      ),
      closedBuilder: (BuildContext context, VoidCallback callback) {
        return Container(
            decoration: BoxDecoration(color: category.color),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(Dimen.padding),
                  child: Text(category.title,
                      style: AppTypography.body().copyWith(fontSize: 18)),
                ),
                Positioned(
                  child: Align(
                      alignment: Alignment.bottomRight,
                      child: Image.asset(
                        category.icon,
                        width: 100,
                        height: 100,
                      )),
                )
              ],
            ));
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  _onPlayButtonPressed() async {
    BlocProvider.of<SoundBloc>(context).add(TogglePlayButton());
  }

  void _soundsPlayingModalBottomSheet(BuildContext buildContext) {
    showModalBottomSheet(
        context: buildContext,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Dimen.cornerRadius),
            topRight: Radius.circular(Dimen.cornerRadius),
          ),
        ),
        backgroundColor: Colors.white,
        builder: (BuildContext _) {
          return BlocProvider.value(
            value: BlocProvider.of<SoundBloc>(buildContext),
            child: _showPlayingsSoundsList()
          );
        }
    );
  }

  Widget _showPlayingsSoundsList() {
    return BlocBuilder<SoundBloc, Result>(
      builder: (context, state) {
        if(state is Success) {

          List<Sound> sounds = (state.value as List<Sound>);

          List<Widget> widgets = [];
          widgets.add(
            Padding(
              padding: EdgeInsets.all(Dimen.padding),
              child: Center(
                child: Text("${Plurals.currentlyPlayingSounds(sounds.length)}",
                    style: AppTypography.body()),
              ),
            )
          );
          widgets.addAll(
              sounds.map((sound) =>
                  PlayingSoundView(sound: sound)
              ).toList()
          );

          return Padding(
            padding: EdgeInsets.symmetric(vertical: Dimen.padding), // give scrollbar padding
            child: Scrollbar(
              isAlwaysShown: true,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Dimen.padding),
                child: SingleChildScrollView(
                  child: Wrap(
                    children: widgets,
                  ),
                ),
              ),
            ),
          );
        }
        return Wrap(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.all(Dimen.padding),
                child: Text("${Plurals.currentlyPlayingSounds(0)}",
                    style: AppTypography.body()),
              ),
            )
          ],
        );
      },
    );
  }
}
