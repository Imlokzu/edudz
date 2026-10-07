// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get loading => '読み込み中';

  @override
  String get mainHome => 'ホーム';

  @override
  String get mainTimetable => '時刻表';

  @override
  String get mainICanteen => 'iCanteen';

  @override
  String get mainMessages => 'メッセージ';

  @override
  String get mainHomework => '宿題';

  @override
  String get mainGrades => '学年';

  @override
  String get homeLunchesNotLoaded => '昼食情報を読み込めませんでした';

  @override
  String get homeNoLunchToday => '今日は利用できるランチがありません';

  @override
  String homeLunchToday(int lunch) {
    return 'あなたのランチオプション番号は $lunch です';
  }

  @override
  String homeLunchDontForget(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString のランチを注文するのを忘れないでください';
  }

  @override
  String get homeLogout => 'ログアウト';

  @override
  String get homeOnboarding => 'オンボーディング';

  @override
  String get homeSetupICanteen => 'iCanteen を設定する';

  @override
  String get homeNoClasses => '今日は学校がありません :D';

  @override
  String get homeUpdateTitle => '新しいバージョンが利用可能です';

  @override
  String get homeUpdateDescription =>
      '最新バージョンをダウンロードするには、https://github.com/DislikesSchool/edudz/releases にアクセスしてください';

  @override
  String get homeQuickstart => 'クイックスタート';

  @override
  String get homePreview => 'プレビュー';

  @override
  String get homePatchAvailable => '新しいパッチをインストールしています…';

  @override
  String get homePatchDownloaded => 'パッチのダウンロードが完了しました。edudz を再起動してください';

  @override
  String get homeDeleteData => 'データを削除する';

  @override
  String get homeDeleteDataTitle => 'データを削除';

  @override
  String get homeDeleteDataConfirmation => 'サーバーにデータ削除をリクエストしてもよろしいですか？';

  @override
  String get homeDeleteDataProcessing => 'データを削除しています…';

  @override
  String get homeDeleteDataSuccess => 'データは正常に削除されました';

  @override
  String get homeDeleteDataError => 'データの削除に失敗しました';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get homeGrades => '成績';

  @override
  String get homeHomework => '宿題';

  @override
  String get homeworkTitle => '宿題';

  @override
  String get messagesTitle => 'メッセージ';

  @override
  String get loginPleaseLogin => 'edudz にログインしてください';

  @override
  String get loginUseExistingCredentials => '既存の EduPage 認証情報を使用してください';

  @override
  String get loginUsername => 'ユーザー名';

  @override
  String get loginPassword => 'パスワード';

  @override
  String get loginServer => 'サーバー（例：school.edupage.org）';

  @override
  String get loginLogin => 'ログイン';

  @override
  String get loggingIn => 'ログイン中…';

  @override
  String get loginCustomEndpointCheckbox => 'カスタムエンドポイントを使用';

  @override
  String get loginCustomEndpoint => 'カスタムエンドポイントURLを入力してください';

  @override
  String get loginDemoButton => 'またはデモを試してください';

  @override
  String get loginCredentialsRequired => 'ユーザー名とパスワードは必須です';

  @override
  String get loginInvalidCredentials => 'ユーザー名またはパスワードが無効です';

  @override
  String get loginServerOptional =>
      'サーバーは任意ですが、正しい認証情報を使用しているのにログインできない場合に役立つ可能性があります';

  @override
  String get setupWelcomeTitle => 'edudz へようこそ';

  @override
  String get setupWelcomeBody =>
      'edudz は、速度・効率性・ユーザー体験に重点を置いた EduPage のモダンなクライアントです。edudz は完全にオープンソースで、無料で使用できます。ニュースやアップデートを受け取るために、ぜひ私たちの Discord サーバーに参加してください。';

  @override
  String get setupQuickStartTitle => 'クイックスタート';

  @override
  String get setupQuickStartExplanation => 'アプリの読み込み時間を大幅に高速化する実験的機能です。';

  @override
  String get setupQuickStartEnable => 'クイックスタートを有効にする';

  @override
  String get setupQuickStartDetails =>
      'クイックスタートを有効にすると、アプリはサーバーからデータを取得するよりもキャッシュされたデータを優先するようになります。この設定は後から無効にすることができます。';

  @override
  String get setupQuickStartInfo => 'クイックスタートはまだ実験段階です';

  @override
  String get setupQuickStartBenefits =>
      'クイックスタートはアプリの起動をほぼ瞬時にし、サーバーの応答を待つ代わりにバックグラウンドでサーバーからデータを取得します。';

  @override
  String get setupQuickStartDrawbacks =>
      'このため、初期読み込み時間は速くなりますが、短時間だけ古いデータが表示される可能性があります。';

  @override
  String get setupDataStorageTitle => 'データストレージ';

  @override
  String get setupDataStorageExplanation =>
      'edudz は、高度な機能を提供するために、一部のユーザーデータを edudz サーバーに保存することができます。この機能がなくてもアプリは問題なく動作しますが、一部の機能が制限される場合があります。';

  @override
  String get setupDataStorageDisabled => 'サーバーへのデータ保存は無効になっています';

  @override
  String get setupDataStorageDisabledExplanation =>
      '接続している edudz サーバーインスタンスではサーバー保存が無効になっています。';

  @override
  String get setupDataStoragePrivacyEncrypted => 'あなたのデータは暗号化されています';

  @override
  String get setupDataStoragePrivacyUnencrypted => 'あなたのデータは暗号化されていません';

  @override
  String get setupDataStoragePrivacyDetailsEncrypted =>
      '接続しているサーバーは、あなたの認証情報を安全かつ暗号化された方法で保存しています。';

  @override
  String get setupDataStoragePrivacyDetailsUnencrypted =>
      '接続しているサーバーはあなたのデータを暗号化していません。サーバー側で暗号化を有効にするか、データを安全に保存するために公式の edudz サーバーを使用することを推奨します。';

  @override
  String get setupDataStorageEnable => 'データストレージを有効にする';

  @override
  String get setupDataStorageChoose => '保存するデータを選択してください';

  @override
  String get setupDataStorageAttendance => 'ユーザーのログイン認証情報';

  @override
  String get setupDataStorageGrades => 'テキストメッセージの保存';

  @override
  String get setupDataStorageMessages => 'タイムラインの保存';

  @override
  String get setupDataStoragePrivacy => 'edudz データストレージのセキュリティ';

  @override
  String get setupDataStoragePrivacyDetails =>
      'edudz サーバーは、専用のプライベートサーバー上でデータを安全かつ暗号化された形で保存します。データは外部の第三者と共有されることはありません。';

  @override
  String get setupFeaturesAvailable => '動作する機能';

  @override
  String get setupFeatureBasic => '基本的なアプリ機能（メッセージ、時間割、成績など）';

  @override
  String get setupFeatureNotifications => 'プッシュ通知';

  @override
  String get setupFeatureSearch => '全文検索';

  @override
  String get setupCompleteTitle => 'セットアップ完了';

  @override
  String get setupCompleteBody => 'セットアップが完了しました。これで edudz を使用できるようになりました。';

  @override
  String get setupDone => 'セットアップ完了';

  @override
  String get today => '今日';

  @override
  String get tomorrow => '明日';

  @override
  String timetableTeacher(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 人の教師',
      one: '教師',
    );
    return '$_temp0';
  }

  @override
  String get loadCredentials => '認証情報を読み込んでいます…';

  @override
  String get loadLoggingIn => 'ログイン中…';

  @override
  String get loadLoggedIn => 'ログインしました';

  @override
  String get loadAccessToken => 'アクセストークンを取得しています…';

  @override
  String get loadVerify => '検証中';

  @override
  String get loadDownloadTimetable => '時間割をダウンロードしています…';

  @override
  String get loadDownloadGrades => '成績をダウンロードしています…';

  @override
  String get loadDownloadMessages => 'メッセージをダウンロードしています…';

  @override
  String get loadDone => '完了！';

  @override
  String get loadError => 'エラー';

  @override
  String get loadErrorDescription => 'データの読み込み中にエラーが発生しました。このエラーは報告されています。';

  @override
  String get iCanteenLoading => '昼食を読み込んでいます（時間がかかる場合があります）';

  @override
  String get iCanteenCantLoad => '「昼食を読み込めませんでした';

  @override
  String get iCanteenSetupPleaseLogin => 'iCanteen にログイン';

  @override
  String get iCanteenSetupDetails =>
      '次の形式のURLアドレス：https://lunches.yourschool.com/login';

  @override
  String get iCanteenSetupServer => 'サーバーアドレス';

  @override
  String get iCanteenSetupEmail => 'ユーザー名';

  @override
  String get iCanteenSetupPassword => 'パスワード';

  @override
  String get iCanteenSetupError => 'ログイン中にエラーが発生しました';

  @override
  String get messagesLoadingAttachment => 'pdfを読み込んでいます…';

  @override
  String messagesAttachments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個の添付ファイル',
      one: '1 添付ファイル',
    );
    return '$_temp0';
  }

  @override
  String get messagesPoll => '投票';

  @override
  String get createMessageDiscard => 'メッセージを破棄しますか？';

  @override
  String get createMessageDiscardDescription => 'メッセージはまだ送信されていません。本当に破棄しますか？';

  @override
  String get createMessageDiscardCancel => 'キャンセル';

  @override
  String get createMessageDiscardDiscard => '破棄';

  @override
  String get createMessageTitle => '新しいメッセージ';

  @override
  String get createMessageSelectRecipient => '宛先を選択';

  @override
  String get createMessageMessageHere => 'ここにメッセージを入力してください';

  @override
  String get createMessageImportant => '重要';

  @override
  String get createMessageIncludePoll => '投票を含める';

  @override
  String get createMessagePollEnableMultiple => '複数回答を許可する';

  @override
  String get createMessageNewPollOptionPlaceholder => '新しい選択肢';

  @override
  String get createMessageErrorSelectRecipient => '宛先を選択してください';

  @override
  String get createMessageErrorNoMessage => 'メッセージを入力してください';

  @override
  String get createMessageSend => '送信';

  @override
  String get createMessageNotifSending => 'メッセージを送信しています';

  @override
  String get createMessageNotifSendingBody => 'メッセージを送信中です…';

  @override
  String get createMessageNotifSent => 'メッセージを送信しました';

  @override
  String get createMessageNotifSentBody => 'メッセージは正常に送信されました';

  @override
  String get createMessageNotifError => 'エラー';

  @override
  String get createMessageNotifErrorBody =>
      'メッセージの送信中に問題が発生しました。この問題は報告されています！';

  @override
  String get qrLoginPleaseLogin => 'edudz QRログイン';

  @override
  String get qrLoginUseExistingCredentials => 'QRコードを使用して edudz にログインしようとしています';

  @override
  String get gradesTitle => '成績';

  @override
  String get messagesSearchTitle => 'メッセージを検索';

  @override
  String get messagesSearchHint => '検索語を入力してください…';

  @override
  String get messagesSearchInstructions => '上に検索語を入力してください';

  @override
  String get messagesNoResults => '結果が見つかりませんでした';
}
