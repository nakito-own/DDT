import 'package:font_awesome_flutter/font_awesome_flutter.dart';

export 'package:font_awesome_flutter/font_awesome_flutter.dart' show FaIconData;

/// Font Awesome Classic (solid) icons used across the DDT interface.
abstract final class DdtIcons {
  DdtIcons._();

  // App sections (navigation rail)
  static const FaIconData tasks = FontAwesomeIcons.check;
  static const FaIconData mail = FontAwesomeIcons.envelope;
  static const FaIconData calendar = FontAwesomeIcons.calendarDays;
  static const FaIconData contacts = FontAwesomeIcons.addressBook;
  static const FaIconData analytics = FontAwesomeIcons.chartColumn;
  static const FaIconData grid = FontAwesomeIcons.tableCells;
  static const FaIconData automations = FontAwesomeIcons.bolt;
  static const FaIconData penToSquare = FontAwesomeIcons.penToSquare;
  static const FaIconData settings = FontAwesomeIcons.gear;

  // Common actions
  static const FaIconData add = FontAwesomeIcons.plus;
  static const FaIconData remove = FontAwesomeIcons.minus;
  static const FaIconData close = FontAwesomeIcons.xmark;
  static const FaIconData closeCircle = FontAwesomeIcons.circleXmark;
  static const FaIconData back = FontAwesomeIcons.arrowLeft;
  static const FaIconData chevronLeft = FontAwesomeIcons.chevronLeft;
  static const FaIconData chevronRight = FontAwesomeIcons.chevronRight;
  static const FaIconData chevronDown = FontAwesomeIcons.chevronDown;
  static const FaIconData check = FontAwesomeIcons.check;
  static const FaIconData checkCircle = FontAwesomeIcons.circleCheck;
  static const FaIconData edit = FontAwesomeIcons.penToSquare;
  static const FaIconData search = FontAwesomeIcons.magnifyingGlass;
  static const FaIconData refresh = FontAwesomeIcons.arrowRotateRight;
  static const FaIconData trash = FontAwesomeIcons.trash;
  static const FaIconData archive = FontAwesomeIcons.boxArchive;
  static const FaIconData filter = FontAwesomeIcons.filter;
  static const FaIconData sort = FontAwesomeIcons.arrowsUpDown;
  static const FaIconData sliders = FontAwesomeIcons.sliders;

  // People & notifications
  static const FaIconData bell = FontAwesomeIcons.bell;
  static const FaIconData user = FontAwesomeIcons.user;
  static const FaIconData userCircle = FontAwesomeIcons.circleUser;

  // Time & place
  static const FaIconData clock = FontAwesomeIcons.clock;
  static const FaIconData location = FontAwesomeIcons.locationDot;
  static const FaIconData calendarDay = FontAwesomeIcons.calendarDay;
  static const FaIconData calendarPlus = FontAwesomeIcons.calendarPlus;

  // Communication
  static const FaIconData comment = FontAwesomeIcons.comment;
  static const FaIconData inbox = FontAwesomeIcons.inbox;
  static const FaIconData flag = FontAwesomeIcons.flag;
  static const FaIconData at = FontAwesomeIcons.at;
  static const FaIconData subject = FontAwesomeIcons.font;
  static const FaIconData paperclip = FontAwesomeIcons.paperclip;
  static const FaIconData link = FontAwesomeIcons.link;

  // Navigation & layout
  static const FaIconData dragHandle = FontAwesomeIcons.bars;
  static const FaIconData arrowUp = FontAwesomeIcons.arrowUp;
  static const FaIconData arrowDown = FontAwesomeIcons.arrowDown;
  static const FaIconData arrowUpRight = FontAwesomeIcons.upRightFromSquare;

  // Status & feedback
  static const FaIconData warning = FontAwesomeIcons.triangleExclamation;
  static const FaIconData info = FontAwesomeIcons.circleInfo;
  static const FaIconData error = FontAwesomeIcons.circleExclamation;
  static const FaIconData success = FontAwesomeIcons.circleCheck;

  // Files & folders
  static const FaIconData folder = FontAwesomeIcons.folder;
  static const FaIconData folderOpen = FontAwesomeIcons.folderOpen;
  static const FaIconData file = FontAwesomeIcons.file;
  static const FaIconData fileLines = FontAwesomeIcons.fileLines;
  static const FaIconData filePdf = FontAwesomeIcons.filePdf;
  static const FaIconData fileImage = FontAwesomeIcons.image;
  static const FaIconData fileAudio = FontAwesomeIcons.fileAudio;
  static const FaIconData fileVideo = FontAwesomeIcons.fileVideo;
  static const FaIconData fileZip = FontAwesomeIcons.fileZipper;
  static const FaIconData fileTable = FontAwesomeIcons.table;
  static const FaIconData drafts = FontAwesomeIcons.filePen;
  static const FaIconData globe = FontAwesomeIcons.globe;
  static const FaIconData book = FontAwesomeIcons.book;

  // Forms & selection
  static const FaIconData visibility = FontAwesomeIcons.eye;
  static const FaIconData visibilityOff = FontAwesomeIcons.eyeSlash;
  static const FaIconData lock = FontAwesomeIcons.lock;
  static const FaIconData selectAll = FontAwesomeIcons.borderAll;
  static const FaIconData deselect = FontAwesomeIcons.squareMinus;
  static const FaIconData radioOn = FontAwesomeIcons.circleDot;
  static const FaIconData radioOff = FontAwesomeIcons.circle;

  // Theme
  static const FaIconData sun = FontAwesomeIcons.sun;
  static const FaIconData moon = FontAwesomeIcons.moon;
}
