
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import CoralFilePickerPlugin from '../plugins/CoralFilePickerPlugin';
import OhosUserApiPlugin from '../plugins/OhosUserApiPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new CoralFilePickerPlugin())
    flutterEngine.getPlugins()?.add(new OhosUserApiPlugin())
  }
}
