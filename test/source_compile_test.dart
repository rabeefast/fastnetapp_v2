import '../lib/core/calculator.dart' as calculator;
import '../lib/core/initial_dropdown_form_field.dart' as dropdown_form_field;
import '../lib/core/phone_auth_identifier.dart' as phone_auth_identifier;
import '../lib/core/router.dart' as router;
import '../lib/core/serial_parser.dart' as serial_parser;
import '../lib/core/theme.dart' as theme;
import '../lib/features/agent/agent_home.dart' as agent_home;
import '../lib/features/auth/loading_page.dart' as loading_page;
import '../lib/features/auth/login_page.dart' as login_page;
import '../lib/features/auth/signup_page.dart' as signup_page;
import '../lib/features/delivery/delivery_wizard.dart' as delivery_wizard;
import '../lib/features/manager/manager_shell.dart' as manager_shell;
import '../lib/features/manager/pages/accounts_page.dart' as accounts_page;
import '../lib/features/manager/pages/batches_page.dart' as batches_page;
import '../lib/features/manager/pages/dashboard_page.dart' as dashboard_page;
import '../lib/features/manager/pages/deliveries_page.dart' as deliveries_page;
import '../lib/features/manager/pages/history_page.dart' as history_page;
import '../lib/features/manager/settings/router_page.dart' as router_page;
import '../lib/features/manager/settings/settings_page.dart' as settings_page;
import '../lib/features/pos/pos_home.dart' as pos_home;
import '../lib/features/sale/sale_dialog.dart' as sale_dialog;
import '../lib/firebase_options.dart' as firebase_options;
import '../lib/main.dart' as app;
import '../lib/models/app_user.dart' as app_user;
import '../lib/models/batch.dart' as batch;
import '../lib/models/card_item.dart' as card_item;
import '../lib/models/category_config.dart' as category_config;
import '../lib/models/delivery.dart' as delivery;
import '../lib/models/payment.dart' as payment;
import '../lib/models/settings_model.dart' as settings_model;
import '../lib/services/auth_service.dart' as auth_service;
import '../lib/services/db_service.dart' as db_service;
import '../lib/services/router_api_service.dart' as router_api_service;
import '../lib/services/router_sync_service.dart' as router_sync_service;
import '../lib/services/telegram_service.dart' as telegram_service;
import '../lib/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all application libraries compile and are importable', () {
    expect(
      calculator.DeliveryCalculator.freeCardsFor(
        category_config.CategoryConfig(
          key: 'test',
          label: 'test',
          umProfile: 'test',
          mgMode: 'card',
          agMode: 'card',
        ),
        2,
      ),
      0,
    );
    // Keep all application modules in the test compilation graph.
    expect(<Object?>[
      router.createRouter,
      dropdown_form_field.InitialDropdownFormField,
      phone_auth_identifier.PhoneAuthIdentifier,
      theme.AppTheme,
      agent_home.AgentHome,
      loading_page.LoadingPage,
      login_page.LoginPage,
      signup_page.SignupPage,
      delivery_wizard.DeliveryWizard,
      manager_shell.ManagerShell,
      accounts_page.AccountsPage,
      batches_page.BatchesPage,
      dashboard_page.DashboardPage,
      deliveries_page.DeliveriesPage,
      history_page.HistoryPage,
      router_page.RouterSettingsPage,
      settings_page.SettingsPage,
      sale_dialog.showSaleDialog,
      serial_parser.parseSerials,
      pos_home.PosHome,
      firebase_options.DefaultFirebaseOptions,
      app.FastNetApp,
      app_user.AppUser,
      batch.Batch,
      card_item.CardItem,
      delivery.Delivery,
      payment.Payment,
      settings_model.SettingsModel,
      auth_service.AuthService,
      db_service.DbService,
      router_api_service.RouterApiClient,
      router_sync_service.RouterSyncService,
      telegram_service.TelegramService,
      app_state.AppState,
    ], hasLength(34));
  });
}
