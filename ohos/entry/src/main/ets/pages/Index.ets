
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'
import { userApiWebController } from '../plugins/UserApiWebRuntime';
import OhosUserApiPlugin from '../plugins/OhosUserApiPlugin';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  build() {
    Stack() {
      FlutterPage({ viewId: this.viewId })
        .width('100%')
        .height('100%')
      Web({ src: 'about:blank', controller: userApiWebController })
        .width(1)
        .height(1)
        .visibility(Visibility.Hidden)
        .javaScriptAccess(true)
        .fileAccess(false)
        .domStorageAccess(false)
        .onControllerAttached(() => OhosUserApiPlugin.onWebReady())
        .onPageBegin(() => OhosUserApiPlugin.onWebDocumentBegin())
        .onPageEnd(() => OhosUserApiPlugin.onWebDocumentReady())
    }.width('100%').height('100%')
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
