import picker from '@ohos.file.picker';
import { AbilityAware, AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

export default class CoralFilePickerPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  getUniqueClassName(): string { return 'CoralFilePickerPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'coral_music/file_access');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(_: FlutterPluginBinding): void { this.channel?.setMethodCallHandler(null); }
  onAttachedToAbility(binding: AbilityPluginBinding): void { this.context = binding.getAbility().context; }
  onDetachedFromAbility(): void { this.context = null; }
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.context === null) {
      result.success(call.method === 'pickAudio' || call.method === 'pickDocuments' ? [] : false);
      return;
    }
    try {
      if (call.method === 'applicationDocumentsPath') {
        result.success(this.context.filesDir);
        return;
      }
      const multiple = call.argument('multiple') === true;
      if (call.method === 'pickAudio') {
        const options = new picker.AudioSelectOptions(); options.maxSelectNumber = multiple ? 500 : 1;
        result.success(await this.copyIntoCache(await new picker.AudioViewPicker(this.context).select(options)));
        return;
      }
      if (call.method === 'pickDocuments') {
        const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = multiple ? 500 : 1;
        options.fileSuffixFilters = call.argument('extensions');
        result.success(await this.copyIntoCache(await new picker.DocumentViewPicker(this.context).select(options)));
        return;
      }
      if (call.method === 'saveDocument') {
        result.success(await this.saveDocument(
          call.argument('content') as string,
          call.argument('fileName') as string,
          call.argument('extensions') as Array<string>,
        ));
        return;
      }
      if (call.method === 'exportFile') {
        result.success(await this.exportFile(
          call.argument('sourcePath') as string,
          call.argument('fileName') as string,
        ));
        return;
      }
      result.notImplemented();
    } catch (_) {
      result.success(call.method === 'pickAudio' || call.method === 'pickDocuments' ? [] : false);
    }
  }

  private async copyIntoCache(uris: Array<string>): Promise<Array<string>> {
    if (this.context === null) return [];
    const files: Array<string> = [];
    for (let index = 0; index < uris.length; index++) {
      const source = uris[index];
      const suffix = source.substring(source.lastIndexOf('.')) || '';
      const rawName = source.substring(source.lastIndexOf('/') + 1).split('?')[0];
      const name = decodeURIComponent(rawName).replace(/[\\/:*?"<>|\x00-\x1F]/g, '_');
      const fileName = name && name !== '.' && name !== '..' ? name : `import${suffix}`;
      const directory = `${this.context.filesDir}/coral-import-${Date.now()}-${index}`;
      await fs.mkdir(directory, true);
      const target = `${directory}/${fileName}`;
      await fs.copy(source, `file://${target}`);
      files.push(target);
    }
    return files;
  }

  private async saveDocument(content: string, fileName: string, extensions: Array<string>): Promise<boolean> {
    if (this.context === null || content.length > 8 * 1024 * 1024) return false;
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = extensions;
    const uris = await new picker.DocumentViewPicker(this.context).save(options);
    if (uris.length === 0) return false;
    const file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      await fs.write(file.fd, content);
      return true;
    } finally {
      await fs.close(file);
    }
  }

  private async exportFile(sourcePath: string, fileName: string): Promise<boolean> {
    if (this.context === null || !sourcePath.startsWith(`${this.context.filesDir}/`)) return false;
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const uris = await new picker.DocumentViewPicker(this.context).save(options);
    if (uris.length === 0) return false;
    await fs.copy(`file://${sourcePath}`, uris[0]);
    return true;
  }
}
