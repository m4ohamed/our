// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Our Love Story`
  String get appName {
    return Intl.message(
      'Our Love Story',
      name: 'appName',
      desc: 'The name of the application',
      args: [],
    );
  }

  /// `Mohamed ❤️ Sara`
  String get coupleName {
    return Intl.message(
      'Mohamed ❤️ Sara',
      name: 'coupleName',
      desc: 'The names of the couple',
      args: [],
    );
  }

  /// `{days} Days Together`
  String daysTogether(int days) {
    return Intl.message(
      '$days Days Together',
      name: 'daysTogether',
      desc: 'Number of days the couple has been together',
      args: [days],
    );
  }

  /// `Wedding Countdown`
  String get weddingCountdown {
    return Intl.message(
      'Wedding Countdown',
      name: 'weddingCountdown',
      desc: 'Title for the wedding countdown section',
      args: [],
    );
  }

  /// `Our Memories`
  String get memories {
    return Intl.message(
      'Our Memories',
      name: 'memories',
      desc: 'Title for the memories section',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: 'Settings label',
      args: [],
    );
  }

  /// `Settings`
  String get settingsTitle {
    return Intl.message(
      'Settings',
      name: 'settingsTitle',
      desc: 'Title for the settings screen',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message(
      'Language',
      name: 'language',
      desc: 'Language setting label',
      args: [],
    );
  }

  /// `Change Language`
  String get changeLanguage {
    return Intl.message(
      'Change Language',
      name: 'changeLanguage',
      desc: 'Change language option',
      args: [],
    );
  }

  /// `Arabic`
  String get arabic {
    return Intl.message(
      'Arabic',
      name: 'arabic',
      desc: 'Arabic language name',
      args: [],
    );
  }

  /// `English`
  String get english {
    return Intl.message(
      'English',
      name: 'english',
      desc: 'English language name',
      args: [],
    );
  }

  /// `Error`
  String get error {
    return Intl.message(
      'Error',
      name: 'error',
      desc: 'General error message title',
      args: [],
    );
  }

  /// `Surprise`
  String get surprise {
    return Intl.message(
      'Surprise',
      name: 'surprise',
      desc: 'Surprise section title',
      args: [],
    );
  }

  /// `Preparing our magic...`
  String get preparingMagic {
    return Intl.message(
      'Preparing our magic...',
      name: 'preparingMagic',
      desc: 'Loading message for surprise section',
      args: [],
    );
  }

  /// `Our Love Story Begins...`
  String get loveStoryBegins {
    return Intl.message(
      'Our Love Story Begins...',
      name: 'loveStoryBegins',
      desc: 'Intro text for the love story',
      args: [],
    );
  }

  /// `You have a secret message...`
  String get secretMessage {
    return Intl.message(
      'You have a secret message...',
      name: 'secretMessage',
      desc: 'Notification message for a secret message',
      args: [],
    );
  }

  /// `Tap to Open`
  String get tapToOpen {
    return Intl.message(
      'Tap to Open',
      name: 'tapToOpen',
      desc: 'Instruction to open a message',
      args: [],
    );
  }

  /// `Save in my Heart`
  String get saveInHeart {
    return Intl.message(
      'Save in my Heart',
      name: 'saveInHeart',
      desc: 'Action to save a message',
      args: [],
    );
  }

  /// `With all my love, {name}`
  String withLove(String name) {
    return Intl.message(
      'With all my love, $name',
      name: 'withLove',
      desc: '',
      args: [name],
    );
  }

  /// `JOURNEY TOGETHER`
  String get journeyTogether {
    return Intl.message(
      'JOURNEY TOGETHER',
      name: 'journeyTogether',
      desc: 'Heading for the journey together section',
      args: [],
    );
  }

  /// `Days of Love`
  String get daysOfLove {
    return Intl.message(
      'Days of Love',
      name: 'daysOfLove',
      desc: 'Label for days of love',
      args: [],
    );
  }

  /// `Timeline`
  String get timeline {
    return Intl.message(
      'Timeline',
      name: 'timeline',
      desc: 'Timeline label',
      args: [],
    );
  }

  /// `Our milestones`
  String get timelineSubtitle {
    return Intl.message(
      'Our milestones',
      name: 'timelineSubtitle',
      desc: 'Subtitle for the timeline',
      args: [],
    );
  }

  /// `Days`
  String get days {
    return Intl.message('Days', name: 'days', desc: '', args: []);
  }

  /// `Hours`
  String get hours {
    return Intl.message('Hours', name: 'hours', desc: '', args: []);
  }

  /// `Minutes`
  String get minutes {
    return Intl.message('Minutes', name: 'minutes', desc: '', args: []);
  }

  /// `Seconds`
  String get seconds {
    return Intl.message('Seconds', name: 'seconds', desc: '', args: []);
  }

  /// `Waiting for Moaz`
  String get waitingForMoaz {
    return Intl.message(
      'Waiting for Moaz',
      name: 'waitingForMoaz',
      desc: '',
      args: [],
    );
  }

  /// `Our first baby`
  String get babyArrivalSubtitle {
    return Intl.message(
      'Our first baby',
      name: 'babyArrivalSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Baby Moaz`
  String get babyArrivalTitle {
    return Intl.message(
      'Baby Moaz',
      name: 'babyArrivalTitle',
      desc: '',
      args: [],
    );
  }

  /// `Days until Moaz arrives`
  String get daysUntilArrival {
    return Intl.message(
      'Days until Moaz arrives',
      name: 'daysUntilArrival',
      desc: '',
      args: [],
    );
  }

  /// `Time until arrival`
  String get timeUntilArrival {
    return Intl.message(
      'Time until arrival',
      name: 'timeUntilArrival',
      desc: '',
      args: [],
    );
  }

  /// `Captured hearts`
  String get memoriesSubtitle {
    return Intl.message(
      'Captured hearts',
      name: 'memoriesSubtitle',
      desc: 'Subtitle for the memories section',
      args: [],
    );
  }

  /// `For you only`
  String get surpriseSubtitle {
    return Intl.message(
      'For you only',
      name: 'surpriseSubtitle',
      desc: 'Subtitle for the surprise section',
      args: [],
    );
  }

  /// `Wait...`
  String get countdown {
    return Intl.message(
      'Wait...',
      name: 'countdown',
      desc: 'Loading/Wait message for countdown',
      args: [],
    );
  }

  /// `Upcoming bliss`
  String get countdownSubtitle {
    return Intl.message(
      'Upcoming bliss',
      name: 'countdownSubtitle',
      desc: 'Subtitle for the countdown',
      args: [],
    );
  }

  /// `"Every moment with you is a cinematic heirloom."`
  String get footerMessage {
    return Intl.message(
      '"Every moment with you is a cinematic heirloom."',
      name: 'footerMessage',
      desc: 'Romantic quote in footer',
      args: [],
    );
  }

  /// `Our Ongoing Love Story`
  String get ongoingLoveStory {
    return Intl.message(
      'Our Ongoing Love Story',
      name: 'ongoingLoveStory',
      desc: 'Label for ongoing story',
      args: [],
    );
  }

  /// `Counting the days to be together`
  String get countingDaysTogether {
    return Intl.message(
      'Counting the days to be together',
      name: 'countingDaysTogether',
      desc: 'Description for countdown',
      args: [],
    );
  }

  /// `Day`
  String get day {
    return Intl.message('Day', name: 'day', desc: 'Singular day', args: []);
  }

  /// `Hour`
  String get hour {
    return Intl.message('Hour', name: 'hour', desc: 'Singular hour', args: []);
  }

  /// `Minute`
  String get minute {
    return Intl.message(
      'Minute',
      name: 'minute',
      desc: 'Singular minute',
      args: [],
    );
  }

  /// `Second`
  String get second {
    return Intl.message(
      'Second',
      name: 'second',
      desc: 'Singular second',
      args: [],
    );
  }

  /// `Since our real journey started`
  String get sinceJourneyStarted {
    return Intl.message(
      'Since our real journey started',
      name: 'sinceJourneyStarted',
      desc: 'Description of start date',
      args: [],
    );
  }

  /// `Memories Album`
  String get albumTitle {
    return Intl.message(
      'Memories Album',
      name: 'albumTitle',
      desc: 'Title for the memories album',
      args: [],
    );
  }

  /// `All`
  String get all {
    return Intl.message(
      'All',
      name: 'all',
      desc: 'Filter label for all items',
      args: [],
    );
  }

  /// `Featured`
  String get featured {
    return Intl.message(
      'Featured',
      name: 'featured',
      desc: 'Filter label for featured items',
      args: [],
    );
  }

  /// `Photos`
  String get photos {
    return Intl.message(
      'Photos',
      name: 'photos',
      desc: 'Filter label for photos',
      args: [],
    );
  }

  /// `Videos`
  String get videos {
    return Intl.message(
      'Videos',
      name: 'videos',
      desc: 'Filter label for videos',
      args: [],
    );
  }

  /// `Every moment is a treasure...`
  String get treasureMoment {
    return Intl.message(
      'Every moment is a treasure...',
      name: 'treasureMoment',
      desc: 'Motto for the album',
      args: [],
    );
  }

  /// `No memories here yet`
  String get noMemoriesYet {
    return Intl.message(
      'No memories here yet',
      name: 'noMemoriesYet',
      desc: 'Empty state message for album',
      args: [],
    );
  }

  /// `Start documenting your moments`
  String get startDocumenting {
    return Intl.message(
      'Start documenting your moments',
      name: 'startDocumenting',
      desc: 'Instruction for empty state',
      args: [],
    );
  }

  /// `Error loading memories`
  String get errorLoadingMemories {
    return Intl.message(
      'Error loading memories',
      name: 'errorLoadingMemories',
      desc: 'Error message for album loading',
      args: [],
    );
  }

  /// `Adding a new memory — Soon!`
  String get addMemorySoon {
    return Intl.message(
      'Adding a new memory — Soon!',
      name: 'addMemorySoon',
      desc: 'Placeholder for adding a memory',
      args: [],
    );
  }

  /// `A beautiful memory`
  String get beautifulMemory {
    return Intl.message(
      'A beautiful memory',
      name: 'beautifulMemory',
      desc: 'Subtitle for a memory item',
      args: [],
    );
  }

  /// `Confirm PIN`
  String get confirmPin {
    return Intl.message(
      'Confirm PIN',
      name: 'confirmPin',
      desc: 'Confirm PIN label',
      args: [],
    );
  }

  /// `Create PIN`
  String get createPin {
    return Intl.message(
      'Create PIN',
      name: 'createPin',
      desc: 'Create PIN label',
      args: [],
    );
  }

  /// `PIN mismatch, try again`
  String get pinMismatch {
    return Intl.message(
      'PIN mismatch, try again',
      name: 'pinMismatch',
      desc: 'PIN mismatch error',
      args: [],
    );
  }

  /// `Re-enter PIN to confirm`
  String get reenterPin {
    return Intl.message(
      'Re-enter PIN to confirm',
      name: 'reenterPin',
      desc: 'Instruction to re-enter PIN',
      args: [],
    );
  }

  /// `Enter 4-digit PIN`
  String get enter4Digits {
    return Intl.message(
      'Enter 4-digit PIN',
      name: 'enter4Digits',
      desc: 'Placeholder for PIN entry',
      args: [],
    );
  }

  /// `Enter PIN`
  String get enterPin {
    return Intl.message(
      'Enter PIN',
      name: 'enterPin',
      desc: 'Label for PIN entry',
      args: [],
    );
  }

  /// `Incorrect PIN ({attempts} attempts remaining)`
  String incorrectPin(int attempts) {
    return Intl.message(
      'Incorrect PIN ($attempts attempts remaining)',
      name: 'incorrectPin',
      desc: '',
      args: [attempts],
    );
  }

  /// `🎵 Audio & Music`
  String get audioAndMusic {
    return Intl.message(
      '🎵 Audio & Music',
      name: 'audioAndMusic',
      desc: 'Title for audio and music settings',
      args: [],
    );
  }

  /// `Play Music`
  String get playMusic {
    return Intl.message(
      'Play Music',
      name: 'playMusic',
      desc: 'Label for play music toggle',
      args: [],
    );
  }

  /// `Romantic background music`
  String get romanticBackgroundMusic {
    return Intl.message(
      'Romantic background music',
      name: 'romanticBackgroundMusic',
      desc: 'Description for background music',
      args: [],
    );
  }

  /// `🔔 Notifications`
  String get notifications {
    return Intl.message(
      '🔔 Notifications',
      name: 'notifications',
      desc: 'Title for notification settings',
      args: [],
    );
  }

  /// `Memories Notifications`
  String get memoriesNotifications {
    return Intl.message(
      'Memories Notifications',
      name: 'memoriesNotifications',
      desc: 'Label for memory notifications',
      args: [],
    );
  }

  /// `Remind of important events`
  String get remindImportantEvents {
    return Intl.message(
      'Remind of important events',
      name: 'remindImportantEvents',
      desc: 'Description for notifications',
      args: [],
    );
  }

  /// `✨ Display & Animations`
  String get displayAndAnimations {
    return Intl.message(
      '✨ Display & Animations',
      name: 'displayAndAnimations',
      desc: 'Title for display and animation settings',
      args: [],
    );
  }

  /// `Animations & Motion`
  String get animationsAndMotion {
    return Intl.message(
      'Animations & Motion',
      name: 'animationsAndMotion',
      desc: 'Label for animation settings',
      args: [],
    );
  }

  /// `Enable visual effects`
  String get enableVisualEffects {
    return Intl.message(
      'Enable visual effects',
      name: 'enableVisualEffects',
      desc: 'Description for visual effects',
      args: [],
    );
  }

  /// `Appearance Mode`
  String get appearanceMode {
    return Intl.message(
      'Appearance Mode',
      name: 'appearanceMode',
      desc: 'Label for appearance mode settings',
      args: [],
    );
  }

  /// `Dark`
  String get dark {
    return Intl.message(
      'Dark',
      name: 'dark',
      desc: 'Dark mode option',
      args: [],
    );
  }

  /// `Light`
  String get light {
    return Intl.message(
      'Light',
      name: 'light',
      desc: 'Light mode option',
      args: [],
    );
  }

  /// `🔒 Security & Privacy`
  String get securityAndPrivacy {
    return Intl.message(
      '🔒 Security & Privacy',
      name: 'securityAndPrivacy',
      desc: 'Title for security settings',
      args: [],
    );
  }

  /// `Lock app with PIN`
  String get lockWithPin {
    return Intl.message(
      'Lock app with PIN',
      name: 'lockWithPin',
      desc: 'Label for PIN lock toggle',
      args: [],
    );
  }

  /// `Enabled — Tap to edit`
  String get enabledTapToEdit {
    return Intl.message(
      'Enabled — Tap to edit',
      name: 'enabledTapToEdit',
      desc: 'Status for enabled PIN',
      args: [],
    );
  }

  /// `Disabled`
  String get disabled {
    return Intl.message(
      'Disabled',
      name: 'disabled',
      desc: 'Status for disabled setting',
      args: [],
    );
  }

  /// `💾 Data Management`
  String get dataManagement {
    return Intl.message(
      '💾 Data Management',
      name: 'dataManagement',
      desc: 'Title for data management section',
      args: [],
    );
  }

  /// `Delete All Data`
  String get deleteAllData {
    return Intl.message(
      'Delete All Data',
      name: 'deleteAllData',
      desc: 'Label for delete all data',
      args: [],
    );
  }

  /// `Reset app completely`
  String get resetAppCompletely {
    return Intl.message(
      'Reset app completely',
      name: 'resetAppCompletely',
      desc: 'Description for reset app',
      args: [],
    );
  }

  /// `ℹ️ App Information`
  String get appInfo {
    return Intl.message(
      'ℹ️ App Information',
      name: 'appInfo',
      desc: 'Title for app information section',
      args: [],
    );
  }

  /// `Version`
  String get version {
    return Intl.message(
      'Version',
      name: 'version',
      desc: 'App version label',
      args: [],
    );
  }

  /// `About App`
  String get aboutApp {
    return Intl.message(
      'About App',
      name: 'aboutApp',
      desc: 'Information about the app',
      args: [],
    );
  }

  /// `Made with love for {name}`
  String madeWithLoveFor(String name) {
    return Intl.message(
      'Made with love for $name',
      name: 'madeWithLoveFor',
      desc: '',
      args: [name],
    );
  }

  /// `Confirm Reset`
  String get confirmReset {
    return Intl.message(
      'Confirm Reset',
      name: 'confirmReset',
      desc: 'Reset confirmation title',
      args: [],
    );
  }

  /// `Are you sure you want to delete all data?\nEvents and settings will be deleted.`
  String get areYouSureDeleteAll {
    return Intl.message(
      'Are you sure you want to delete all data?\nEvents and settings will be deleted.',
      name: 'areYouSureDeleteAll',
      desc: 'Warning message for deleting all data',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: 'Cancel button label',
      args: [],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: 'Delete button label',
      args: [],
    );
  }

  /// `All data has been cleared`
  String get dataCleared {
    return Intl.message(
      'All data has been cleared',
      name: 'dataCleared',
      desc: 'Success message after clearing data',
      args: [],
    );
  }

  /// `A dedicated app for documenting the love story of {name}.`
  String appDescription(String name) {
    return Intl.message(
      'A dedicated app for documenting the love story of $name.',
      name: 'appDescription',
      desc: '',
      args: [name],
    );
  }

  /// `Built with Flutter using Clean Architecture + Riverpod.`
  String get builtWithFlutter {
    return Intl.message(
      'Built with Flutter using Clean Architecture + Riverpod.',
      name: 'builtWithFlutter',
      desc: 'Technical description of the app',
      args: [],
    );
  }

  /// `Our Journey`
  String get ourJourney {
    return Intl.message(
      'Our Journey',
      name: 'ourJourney',
      desc: 'Title for the journey section',
      args: [],
    );
  }

  /// `Sort by Date`
  String get sortDate {
    return Intl.message(
      'Sort by Date',
      name: 'sortDate',
      desc: 'Label for sorting by date',
      args: [],
    );
  }

  /// `Add Memory`
  String get addMemory {
    return Intl.message(
      'Add Memory',
      name: 'addMemory',
      desc: 'Button label to add a memory',
      args: [],
    );
  }

  /// `Our Beautiful Milestones`
  String get beautifulMilestones {
    return Intl.message(
      'Our Beautiful Milestones',
      name: 'beautifulMilestones',
      desc: 'Title for the milestones section',
      args: [],
    );
  }

  /// `{count} Moments engraved in the heart`
  String momentsInHeart(int count) {
    return Intl.message(
      '$count Moments engraved in the heart',
      name: 'momentsInHeart',
      desc: '',
      args: [count],
    );
  }

  /// `And the story has not ended yet...`
  String get storyNotEnded {
    return Intl.message(
      'And the story has not ended yet...',
      name: 'storyNotEnded',
      desc: 'Placeholder for ongoing journey',
      args: [],
    );
  }

  /// `Start writing your love story`
  String get startWritingStory {
    return Intl.message(
      'Start writing your love story',
      name: 'startWritingStory',
      desc: 'Encouragement for empty state',
      args: [],
    );
  }

  /// `Add First Memory`
  String get addFirstMemory {
    return Intl.message(
      'Add First Memory',
      name: 'addFirstMemory',
      desc: 'Button label to add the first memory',
      args: [],
    );
  }

  /// `Confirm Deletion`
  String get confirmDeletion {
    return Intl.message(
      'Confirm Deletion',
      name: 'confirmDeletion',
      desc: 'Title for delete confirmation',
      args: [],
    );
  }

  /// `Are you sure you want to delete "{title}"?`
  String areYouSureDeleteEvent(String title) {
    return Intl.message(
      'Are you sure you want to delete "$title"?',
      name: 'areYouSureDeleteEvent',
      desc: '',
      args: [title],
    );
  }

  /// `"{title}" has been deleted`
  String eventDeleted(String title) {
    return Intl.message(
      '"$title" has been deleted',
      name: 'eventDeleted',
      desc: '',
      args: [title],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message(
      'Edit',
      name: 'edit',
      desc: 'Edit button label',
      args: [],
    );
  }

  /// `January`
  String get january {
    return Intl.message(
      'January',
      name: 'january',
      desc: 'Month of January',
      args: [],
    );
  }

  /// `February`
  String get february {
    return Intl.message(
      'February',
      name: 'february',
      desc: 'Month of February',
      args: [],
    );
  }

  /// `March`
  String get march {
    return Intl.message(
      'March',
      name: 'march',
      desc: 'Month of March',
      args: [],
    );
  }

  /// `April`
  String get april {
    return Intl.message(
      'April',
      name: 'april',
      desc: 'Month of April',
      args: [],
    );
  }

  /// `May`
  String get may {
    return Intl.message('May', name: 'may', desc: 'Month of May', args: []);
  }

  /// `June`
  String get june {
    return Intl.message('June', name: 'june', desc: 'Month of June', args: []);
  }

  /// `July`
  String get july {
    return Intl.message('July', name: 'july', desc: 'Month of July', args: []);
  }

  /// `August`
  String get august {
    return Intl.message(
      'August',
      name: 'august',
      desc: 'Month of August',
      args: [],
    );
  }

  /// `September`
  String get september {
    return Intl.message(
      'September',
      name: 'september',
      desc: 'Month of September',
      args: [],
    );
  }

  /// `October`
  String get october {
    return Intl.message(
      'October',
      name: 'october',
      desc: 'Month of October',
      args: [],
    );
  }

  /// `November`
  String get november {
    return Intl.message(
      'November',
      name: 'november',
      desc: 'Month of November',
      args: [],
    );
  }

  /// `December`
  String get december {
    return Intl.message(
      'December',
      name: 'december',
      desc: 'Month of December',
      args: [],
    );
  }

  /// `{season} Season`
  String season(String season) {
    return Intl.message(
      '$season Season',
      name: 'season',
      desc: '',
      args: [season],
    );
  }

  /// `{count} days ago`
  String daysAgo(int count) {
    return Intl.message(
      '$count days ago',
      name: 'daysAgo',
      desc: '',
      args: [count],
    );
  }

  /// `Demo`
  String get demo {
    return Intl.message(
      'Demo',
      name: 'demo',
      desc: 'Label for demo events',
      args: [],
    );
  }

  /// `Winter`
  String get winter {
    return Intl.message(
      'Winter',
      name: 'winter',
      desc: 'Season: Winter',
      args: [],
    );
  }

  /// `Spring`
  String get spring {
    return Intl.message(
      'Spring',
      name: 'spring',
      desc: 'Season: Spring',
      args: [],
    );
  }

  /// `Summer`
  String get summer {
    return Intl.message(
      'Summer',
      name: 'summer',
      desc: 'Season: Summer',
      args: [],
    );
  }

  /// `Autumn`
  String get autumn {
    return Intl.message(
      'Autumn',
      name: 'autumn',
      desc: 'Season: Autumn',
      args: [],
    );
  }

  /// `Edit Event`
  String get editEvent {
    return Intl.message(
      'Edit Event',
      name: 'editEvent',
      desc: 'Title for edit event screen',
      args: [],
    );
  }

  /// `Add New Memory`
  String get addNewMemory {
    return Intl.message(
      'Add New Memory',
      name: 'addNewMemory',
      desc: 'Title for add event screen',
      args: [],
    );
  }

  /// `Event Title`
  String get eventTitle {
    return Intl.message(
      'Event Title',
      name: 'eventTitle',
      desc: 'Field label for event title',
      args: [],
    );
  }

  /// `Example: First meeting`
  String get exampleFirstMeet {
    return Intl.message(
      'Example: First meeting',
      name: 'exampleFirstMeet',
      desc: 'Placeholder for event title',
      args: [],
    );
  }

  /// `Please enter a title`
  String get enterTitleError {
    return Intl.message(
      'Please enter a title',
      name: 'enterTitleError',
      desc: 'Error message for empty title',
      args: [],
    );
  }

  /// `Description`
  String get description {
    return Intl.message(
      'Description',
      name: 'description',
      desc: 'Field label for description',
      args: [],
    );
  }

  /// `Write details of this memory...`
  String get writeDetails {
    return Intl.message(
      'Write details of this memory...',
      name: 'writeDetails',
      desc: 'Placeholder for description',
      args: [],
    );
  }

  /// `Please enter a description`
  String get enterDescError {
    return Intl.message(
      'Please enter a description',
      name: 'enterDescError',
      desc: 'Error message for empty description',
      args: [],
    );
  }

  /// `Location (Optional)`
  String get locationOptional {
    return Intl.message(
      'Location (Optional)',
      name: 'locationOptional',
      desc: 'Field label for location',
      args: [],
    );
  }

  /// `Example: Family Home`
  String get exampleFamilyHome {
    return Intl.message(
      'Example: Family Home',
      name: 'exampleFamilyHome',
      desc: 'Placeholder for location',
      args: [],
    );
  }

  /// `Event Date`
  String get eventDate {
    return Intl.message(
      'Event Date',
      name: 'eventDate',
      desc: 'Field label for event date',
      args: [],
    );
  }

  /// `Event Icon`
  String get eventIcon {
    return Intl.message(
      'Event Icon',
      name: 'eventIcon',
      desc: 'Field label for event icon',
      args: [],
    );
  }

  /// `Save Changes`
  String get saveChanges {
    return Intl.message(
      'Save Changes',
      name: 'saveChanges',
      desc: 'Button label to save changes',
      args: [],
    );
  }

  /// `Add Event`
  String get addEvent {
    return Intl.message(
      'Add Event',
      name: 'addEvent',
      desc: 'Button label to add event',
      args: [],
    );
  }

  /// `Error saving: {error}`
  String saveError(String error) {
    return Intl.message(
      'Error saving: $error',
      name: 'saveError',
      desc: '',
      args: [error],
    );
  }

  /// `Pregnancy`
  String get pregnancy {
    return Intl.message(
      'Pregnancy',
      name: 'pregnancy',
      desc: '',
      args: [],
    );
  }

  /// `Biometric Unlock`
  String get biometricUnlock {
    return Intl.message(
      'Biometric Unlock',
      name: 'biometricUnlock',
      desc: '',
      args: [],
    );
  }

  /// `Use fingerprint or face`
  String get biometricSubtitle {
    return Intl.message(
      'Use fingerprint or face',
      name: 'biometricSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Please authenticate to unlock Our Love Story`
  String get biometricReason {
    return Intl.message(
      'Please authenticate to unlock Our Love Story',
      name: 'biometricReason',
      desc: '',
      args: [],
    );
  }

  /// `Choose Image Source`
  String get chooseImageSource {
    return Intl.message(
      'Choose Image Source',
      name: 'chooseImageSource',
      desc: '',
      args: [],
    );
  }

  /// `Camera`
  String get camera {
    return Intl.message(
      'Camera',
      name: 'camera',
      desc: '',
      args: [],
    );
  }

  /// `Photo Gallery`
  String get gallery {
    return Intl.message(
      'Photo Gallery',
      name: 'gallery',
      desc: '',
      args: [],
    );
  }

  /// `Image URL (Optional)`
  String get imageUrlOptional {
    return Intl.message(
      'Image URL (Optional)',
      name: 'imageUrlOptional',
      desc: '',
      args: [],
    );
  }

  /// `Pick Image from Device`
  String get pickImageFromDevice {
    return Intl.message(
      'Pick Image from Device',
      name: 'pickImageFromDevice',
      desc: '',
      args: [],
    );
  }

  /// `Remove Image`
  String get removeImage {
    return Intl.message(
      'Remove Image',
      name: 'removeImage',
      desc: '',
      args: [],
    );
  }

  /// `Mark as Featured`
  String get markAsFeatured {
    return Intl.message(
      'Mark as Featured',
      name: 'markAsFeatured',
      desc: '',
      args: [],
    );
  }

  /// `Saved in My Heart`
  String get savedMessages {
    return Intl.message(
      'Saved in My Heart',
      name: 'savedMessages',
      desc: '',
      args: [],
    );
  }

  /// `Add Secret Message`
  String get addSecretMessage {
    return Intl.message(
      'Add Secret Message',
      name: 'addSecretMessage',
      desc: '',
      args: [],
    );
  }

  /// `Write a secret love message...`
  String get writeSecretMessage {
    return Intl.message(
      'Write a secret love message...',
      name: 'writeSecretMessage',
      desc: '',
      args: [],
    );
  }

  /// `Message saved in your heart ❤️`
  String get messageSavedInHeart {
    return Intl.message(
      'Message saved in your heart ❤️',
      name: 'messageSavedInHeart',
      desc: '',
      args: [],
    );
  }

  /// `No saved messages yet`
  String get noSavedMessagesYet {
    return Intl.message(
      'No saved messages yet',
      name: 'noSavedMessagesYet',
      desc: '',
      args: [],
    );
  }

  /// `Newest First`
  String get sortNewestFirst {
    return Intl.message(
      'Newest First',
      name: 'sortNewestFirst',
      desc: '',
      args: [],
    );
  }

  /// `Oldest First`
  String get sortOldestFirst {
    return Intl.message(
      'Oldest First',
      name: 'sortOldestFirst',
      desc: '',
      args: [],
    );
  }

  /// `Upcoming Milestone`
  String get upcomingAnniversary {
    return Intl.message(
      'Upcoming Milestone',
      name: 'upcomingAnniversary',
      desc: '',
      args: [],
    );
  }

  /// `Tags (comma-separated)`
  String get tagsOptional {
    return Intl.message(
      'Tags (comma-separated)',
      name: 'tagsOptional',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: '',
      args: [],
    );
  }

  /// `Too many attempts, wait {seconds}s`
  String tooManyAttempts(int seconds) {
    return Intl.message(
      'Too many attempts, wait ${seconds}s',
      name: 'tooManyAttempts',
      desc: '',
      args: [seconds],
    );
  }

  /// `Welcome {name}! 🎉`
  String welcomeBaby(String name) {
    return Intl.message(
      'Welcome $name! 🎉',
      name: 'welcomeBaby',
      desc: '',
      args: [name],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ar'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
