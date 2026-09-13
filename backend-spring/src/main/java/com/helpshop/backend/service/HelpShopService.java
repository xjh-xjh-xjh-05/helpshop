package com.helpshop.backend.service;

import com.helpshop.backend.entity.AccountEntity;
import com.helpshop.backend.entity.AdminProfileEntity;
import com.helpshop.backend.entity.AddressEntity;
import com.helpshop.backend.entity.AuditLogEntity;
import com.helpshop.backend.entity.ChildProfileEntity;
import com.helpshop.backend.entity.CustomerServiceProfileEntity;
import com.helpshop.backend.entity.ElderlyProfileEntity;
import com.helpshop.backend.entity.FamilyBindingEntity;
import com.helpshop.backend.entity.OrderEntity;
import com.helpshop.backend.entity.PaymentRecordEntity;
import com.helpshop.backend.entity.ProductEntity;
import com.helpshop.backend.entity.ReminderEntity;
import com.helpshop.backend.entity.TicketEntity;
import com.helpshop.backend.entity.SyncEventEntity;
import com.helpshop.backend.entity.NotificationEntity;
import com.helpshop.backend.repository.AccountRepository;
import com.helpshop.backend.repository.AdminProfileRepository;
import com.helpshop.backend.repository.AddressRepository;
import com.helpshop.backend.repository.AuditLogRepository;
import com.helpshop.backend.repository.ChildProfileRepository;
import com.helpshop.backend.repository.CustomerServiceProfileRepository;
import com.helpshop.backend.repository.ElderlyProfileRepository;
import com.helpshop.backend.repository.FamilyBindingRepository;
import com.helpshop.backend.repository.OrderRepository;
import com.helpshop.backend.repository.PaymentRecordRepository;
import com.helpshop.backend.repository.ProductRepository;
import com.helpshop.backend.repository.ReminderRepository;
import com.helpshop.backend.repository.TicketRepository;
import com.helpshop.backend.repository.SyncEventRepository;
import com.helpshop.backend.repository.NotificationRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import javax.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class HelpShopService {
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Value("${spring.datasource.url:}")
    private String datasourceUrl;

    private final AccountRepository accountRepository;
    private final FamilyBindingRepository bindingRepository;
    private final AddressRepository addressRepository;
    private final ProductRepository productRepository;
    private final OrderRepository orderRepository;
    private final ReminderRepository reminderRepository;
    private final AuditLogRepository auditLogRepository;
    private final PaymentRecordRepository paymentRecordRepository;
    private final ElderlyProfileRepository elderlyProfileRepository;
    private final ChildProfileRepository childProfileRepository;
    private final AdminProfileRepository adminProfileRepository;
    private final CustomerServiceProfileRepository csProfileRepository;
    private final TicketRepository ticketRepository;
    private final SyncEventRepository syncEventRepository;
    private final NotificationRepository notificationRepository;
    private final JwtTokenService jwtTokenService;
    private final PasswordEncoder passwordEncoder;

    public HelpShopService(
            AccountRepository accountRepository,
            FamilyBindingRepository bindingRepository,
            AddressRepository addressRepository,
            ProductRepository productRepository,
            OrderRepository orderRepository,
            ReminderRepository reminderRepository,
            AuditLogRepository auditLogRepository,
            PaymentRecordRepository paymentRecordRepository,
            ElderlyProfileRepository elderlyProfileRepository,
            ChildProfileRepository childProfileRepository,
            AdminProfileRepository adminProfileRepository,
            CustomerServiceProfileRepository csProfileRepository,
            TicketRepository ticketRepository,
            SyncEventRepository syncEventRepository,
            NotificationRepository notificationRepository,
            JwtTokenService jwtTokenService,
            PasswordEncoder passwordEncoder) {
        this.accountRepository = accountRepository;
        this.bindingRepository = bindingRepository;
        this.addressRepository = addressRepository;
        this.productRepository = productRepository;
        this.orderRepository = orderRepository;
        this.reminderRepository = reminderRepository;
        this.auditLogRepository = auditLogRepository;
        this.paymentRecordRepository = paymentRecordRepository;
        this.elderlyProfileRepository = elderlyProfileRepository;
        this.childProfileRepository = childProfileRepository;
        this.adminProfileRepository = adminProfileRepository;
        this.csProfileRepository = csProfileRepository;
        this.ticketRepository = ticketRepository;
        this.syncEventRepository = syncEventRepository;
        this.notificationRepository = notificationRepository;
        this.jwtTokenService = jwtTokenService;
        this.passwordEncoder = passwordEncoder;
    }

    @PostConstruct
    @Transactional
    public void seed() {
        if (accountRepository.count() == 0) {
            accountRepository.save(account("acct-elderly-001", "13800000001", "123456", "徐叔叔", "elderly"));
            accountRepository.save(account("acct-child-001", "13900000001", "123456", "徐女士", "child"));
            accountRepository.save(account("acct-admin-001", "13700000001", "123456", "王管理", "admin"));
            accountRepository.save(account("acct-cs-001", "13600000001", "123456", "李客服", "customer_service"));
            bindingRepository.save(binding("binding-001", "acct-elderly-001", "acct-child-001", "HS2026"));
            addressRepository.save(address("addr-001", "acct-elderly-001", "acct-child-001", "徐叔叔", "138****6688", "上海市浦东新区康桥镇安心小区 12 号楼 302 室", 1));
            elderlyProfileRepository.save(elderlyProfile("elderly-profile-001", "acct-elderly-001", "徐叔叔", 68, 1, "13900000001", "HS2026"));
            childProfileRepository.save(childProfile("child-profile-001", "acct-child-001", "徐女士", "子女", 1));
            adminProfileRepository.save(adminProfile("admin-profile-001", "acct-admin-001", "王管理", "运营管理部", "account_manage,audit_view,system_config"));
            csProfileRepository.save(csProfile("cs-profile-001", "acct-cs-001", "李客服", "综合服务组", 10, "active"));
        }
        repairDemoAccounts();
        if (productRepository.count() == 0) {
            seedProducts();
        }
        if (ticketRepository.count() == 0) {
            seedTickets();
        }
    }

    private void repairDemoAccounts() {
        AccountEntity elderly = accountRepository.findByPhone("13800000001").orElse(null);
        if (elderly != null && (elderly.password == null || elderly.password.length() == 0)) {
            elderly.password = encodePassword("123456");
            elderly.displayName = elderly.displayName == null || elderly.displayName.length() == 0 ? "徐叔叔" : elderly.displayName;
            elderly.defaultRole = "elderly";
            elderly.status = "active";
            elderly.updatedAt = now();
            accountRepository.save(elderly);
        }
        AccountEntity child = accountRepository.findByPhone("13900000001").orElse(null);
        if (child != null && (child.password == null || child.password.length() == 0)) {
            child.password = encodePassword("123456");
            child.displayName = child.displayName == null || child.displayName.length() == 0 ? "徐女士" : child.displayName;
            child.defaultRole = "child";
            child.status = "active";
            child.updatedAt = now();
            accountRepository.save(child);
        }
        if (elderly != null && child != null && !bindingRepository.findByElderlyAccountIdAndChildAccountIdAndStatus(elderly.id, child.id, "active").isPresent()) {
            bindingRepository.save(binding("binding-001", elderly.id, child.id, "HS2026"));
        }
        if (elderly != null && addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderly.id).isEmpty()) {
            addressRepository.save(address("addr-001", elderly.id, child == null ? "" : child.id, "徐叔叔", "138****6688", "上海市浦东新区康桥镇安心小区 12 号楼 302 室", 1));
        }
        if (elderly != null && !elderlyProfileRepository.findByAccountId(elderly.id).isPresent()) {
            elderlyProfileRepository.save(elderlyProfile("elderly-profile-001", elderly.id, elderly.displayName, 68, 1, child == null ? "" : child.phone, bindingCodeFor(elderly)));
        }
        if (child != null && !childProfileRepository.findByAccountId(child.id).isPresent()) {
            childProfileRepository.save(childProfile("child-profile-001", child.id, child.displayName, "子女", 1));
        }
        AccountEntity admin = accountRepository.findByPhone("13700000001").orElse(null);
        if (admin != null && (admin.password == null || admin.password.length() == 0)) {
            admin.password = encodePassword("123456");
            admin.displayName = admin.displayName == null || admin.displayName.length() == 0 ? "王管理" : admin.displayName;
            admin.defaultRole = "admin";
            admin.status = "active";
            admin.updatedAt = now();
            accountRepository.save(admin);
        }
        if (admin != null && !adminProfileRepository.findByAccountId(admin.id).isPresent()) {
            adminProfileRepository.save(adminProfile("admin-profile-001", admin.id, admin.displayName == null ? "王管理" : admin.displayName, "运营管理部", "account_manage,audit_view,system_config"));
        }
        AccountEntity cs = accountRepository.findByPhone("13600000001").orElse(null);
        if (cs != null && (cs.password == null || cs.password.length() == 0)) {
            cs.password = encodePassword("123456");
            cs.displayName = cs.displayName == null || cs.displayName.length() == 0 ? "李客服" : cs.displayName;
            cs.defaultRole = "customer_service";
            cs.status = "active";
            cs.updatedAt = now();
            accountRepository.save(cs);
        }
        if (cs != null && !csProfileRepository.findByAccountId(cs.id).isPresent()) {
            csProfileRepository.save(csProfile("cs-profile-001", cs.id, cs.displayName == null ? "李客服" : cs.displayName, "综合服务组", 10, "active"));
        }
    }

    public Map<String, Object> index() {
        return map("success", true, "name", "HelpShop Spring Boot Backend", "message", "backend is running", "health", "/health");
    }

    public Map<String, Object> health() {
        return map("status", "ok", "backend", "spring-boot", "db", databaseMode(), "time", now());
    }

    private String databaseMode() {
        String url = datasourceUrl == null ? "" : datasourceUrl.toLowerCase();
        if (url.contains(":mysql:")) {
            return "mysql-jpa";
        }
        if (url.contains(":h2:")) {
            return "h2-jpa-file";
        }
        return "unknown";
    }

    public Map<String, Object> sendSmsCode(Map<String, Object> body) {
        String phone = text(body, "phone");
        require(phone.length() > 0, HttpStatus.BAD_REQUEST, "phone is required");
        String code = String.valueOf(100000 + Math.abs(phone.hashCode()) % 900000);
        return map("success", true, "message", "demo sms code generated", "demo_code", code, "expires_in", 300);
    }

    @Transactional
    public Map<String, Object> register(Map<String, Object> body) {
        String phone = text(body, "phone");
        String password = text(body, "password");
        String displayName = text(body, "display_name");
        String role = roleOrUnverified(defaultText(body, "role", "unverified"));
        require(phone.length() > 0 && password.length() > 0 && displayName.length() > 0, HttpStatus.BAD_REQUEST, "phone, password and display_name are required");
        require(!accountRepository.findByPhone(phone).isPresent(), HttpStatus.CONFLICT, "phone already registered");
        AccountEntity account = account(id("acct"), phone, encodePassword(password), displayName, role);
        accountRepository.save(account);
        audit(account.id, "elderly".equals(role) ? account.id : null, "auth.register", "register " + phone);
        return authResponse(account);
    }

    @Transactional
    public Map<String, Object> login(Map<String, Object> body) {
        String phone = text(body, "phone");
        String password = text(body, "password");
        AccountEntity account = accountRepository.findByPhone(phone).orElse(null);
        require(account != null && passwordMatches(password, account.password), HttpStatus.UNAUTHORIZED, "invalid phone or password");
        upgradePasswordIfNeeded(account, password);
        audit(account.id, "elderly".equals(account.defaultRole) ? account.id : null, "auth.login", "login " + phone);
        return authResponse(account);
    }

    public Map<String, Object> me(String authorization) {
        return map("success", true, "account", accountMap(currentAccount(authorization)));
    }

    @Transactional
    public Map<String, Object> certify(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String role = text(body, "role");
        require("elderly".equals(role) || "child".equals(role) || "admin".equals(role) || "customer_service".equals(role), HttpStatus.BAD_REQUEST, "role must be elderly, child, admin or customer_service");
        account.defaultRole = role;
        account.updatedAt = now();
        accountRepository.save(account);
        ensureProfileForRole(account, role);
        audit(account.id, "elderly".equals(role) ? account.id : null, "auth.certify", "certify " + role);
        return authResponse(account);
    }

    @Transactional
    public Map<String, Object> huaweiLogin(Map<String, Object> body) {
        String openId = text(body, "open_id");
        String unionId = text(body, "union_id");
        require(openId.length() > 0, HttpStatus.BAD_REQUEST, "open_id is required");
        AccountEntity account = accountRepository.findAll().stream()
                .filter(a -> openId.equals(a.huaweiOpenId))
                .findFirst()
                .orElse(null);
        if (account == null) {
            account = new AccountEntity();
            account.id = id("acct");
            account.idUser = 0;
            account.phone = huaweiPlaceholderPhone(openId);
            account.password = encodePassword(id("pwd"));
            account.displayName = "华为用户";
            account.defaultRole = "unverified";
            account.status = "active";
            account.huaweiOpenId = openId;
            account.huaweiUnionId = unionId;
            account.createdAt = now();
            account.updatedAt = now();
            accountRepository.save(account);
            audit(account.id, null, "auth.huawei_register", "huawei login register " + openId);
        } else {
            if (unionId.length() > 0 && !unionId.equals(account.huaweiUnionId)) {
                account.huaweiUnionId = unionId;
                account.updatedAt = now();
                accountRepository.save(account);
            }
            audit(account.id, "elderly".equals(account.defaultRole) ? account.id : null, "auth.huawei_login", "huawei login " + openId);
        }
        Map<String, Object> resp = authResponse(account);
        boolean phoneMissing = isPhoneMissing(account.phone);
        resp.put("phone_missing", phoneMissing);
        if (phoneMissing) {
            resp.put("message", "请绑定手机号");
        }
        return resp;
    }

    @Transactional
    public Map<String, Object> linkPhone(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String phone = text(body, "phone");
        require(phone.length() > 0, HttpStatus.BAD_REQUEST, "phone is required");
        Optional<AccountEntity> existing = accountRepository.findByPhone(phone);
        require(!existing.isPresent() || existing.get().id.equals(account.id), HttpStatus.CONFLICT, "phone already registered");
        account.phone = phone;
        account.updatedAt = now();
        accountRepository.save(account);
        audit(account.id, "elderly".equals(account.defaultRole) ? account.id : null, "auth.link_phone", "link phone " + phone);
        return authResponse(account);
    }

    @Transactional
    public Map<String, Object> bindFamily(String authorization, Map<String, Object> body) {
        AccountEntity child = currentAccount(authorization);
        require("child".equals(child.defaultRole), HttpStatus.FORBIDDEN, "only child account can bind elderly");
        String keyword = text(body, "keyword");
        AccountEntity elderly = findElderly(keyword);
        require(elderly != null, HttpStatus.NOT_FOUND, "elderly account not found");
        String bindingCode = bindingCodeFor(elderly);
        FamilyBindingEntity binding = bindingRepository.findByElderlyAccountIdAndChildAccountIdAndStatus(elderly.id, child.id, "active")
                .orElseGet(() -> binding(id("binding"), elderly.id, child.id, bindingCode));
        bindingRepository.save(binding);
        audit(child.id, elderly.id, "family.bind", "bind elderly " + elderly.id);
        return map("success", true, "message", "bind success", "binding", bindingMap(binding), "elderly", accountMap(elderly));
    }

    public Map<String, Object> listFamilyBindings(String authorization) {
        AccountEntity account = currentAccount(authorization);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (FamilyBindingEntity binding : bindingRepository.findByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active")) {
            Map<String, Object> item = bindingMap(binding);
            AccountEntity elderly = accountRepository.findById(binding.elderlyAccountId).orElse(null);
            item.put("elderly_name", elderly == null ? "" : elderly.displayName);
            item.put("elderly_phone", elderly == null ? "" : elderly.phone);
            rows.add(item);
        }
        return map("success", true, "bindings", rows);
    }

    public Map<String, Object> listAddresses(String authorization) {
        return map("success", true, "addresses", addressMaps(currentElderlyId(currentAccount(authorization))));
    }

    @Transactional
    public Map<String, Object> createAddress(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        String receiver = text(body, "receiver");
        String phone = text(body, "phone");
        String detail = text(body, "detail");
        require(receiver.length() > 0 && phone.length() > 0 && detail.length() > 0, HttpStatus.BAD_REQUEST, "receiver, phone and detail are required");
        int isDefault = addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId).isEmpty() ? 1 : 0;
        AddressEntity address = address(id("addr"), elderlyId, account.id, receiver, phone, detail, isDefault);
        addressRepository.save(address);
        sync(elderlyId, "address.created", "address_id=" + address.id);
        return map("success", true, "address_id", address.id, "addresses", addressMaps(elderlyId));
    }

    @Transactional
    public Map<String, Object> setDefaultAddress(String authorization, Map<String, Object> body) {
        String elderlyId = currentElderlyId(currentAccount(authorization));
        String addressId = text(body, "id");
        AddressEntity target = ownedAddress(addressId, elderlyId);
        for (AddressEntity address : addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId)) {
            address.isDefault = address.id.equals(target.id) ? 1 : 0;
            address.updatedAt = now();
            addressRepository.save(address);
        }
        sync(elderlyId, "address.default", "address_id=" + addressId);
        return map("success", true, "message", "default address updated", "addresses", addressMaps(elderlyId));
    }

    @Transactional
    public Map<String, Object> deleteAddress(String authorization, Map<String, Object> body) {
        String elderlyId = currentElderlyId(currentAccount(authorization));
        String addressId = text(body, "id");
        AddressEntity target = ownedAddress(addressId, elderlyId);
        addressRepository.delete(target);
        List<AddressEntity> remain = addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId);
        if (!remain.isEmpty()) {
            remain.get(0).isDefault = 1;
            addressRepository.save(remain.get(0));
        }
        sync(elderlyId, "address.deleted", "address_id=" + addressId);
        return map("success", true, "message", "address deleted", "addresses", addressMaps(elderlyId));
    }

    public Map<String, Object> listProducts() {
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (ProductEntity product : productRepository.findAllByOrderBySalesDescRatingDesc()) {
            rows.add(productMap(product, 0));
        }
        return map("success", true, "products", rows);
    }

    public Map<String, Object> productDetail(String productId) {
        ProductEntity product = product(productId);
        return map("success", true, "product", productMap(product, 0));
    }

    public Map<String, Object> compare(Map<String, Object> body) {
        String query = defaultText(body, "query", text(body, "text"));
        require(query.length() > 0, HttpStatus.BAD_REQUEST, "query is required");
        Map<String, Object> intent = parseIntent(query);
        List<ProductEntity> matched = searchProducts(intent);
        boolean fallback = matched.isEmpty();
        if (fallback) {
            matched = productRepository.findAllByOrderBySalesDescRatingDesc();
        }
        List<Map<String, Object>> candidates = new ArrayList<Map<String, Object>>();
        for (ProductEntity product : matched) {
            candidates.add(productMap(product, score(product)));
        }
        Collections.sort(candidates, new Comparator<Map<String, Object>>() {
            public int compare(Map<String, Object> a, Map<String, Object> b) {
                return Double.compare(num(b.get("recommend_score")), num(a.get("recommend_score")));
            }
        });
        if (candidates.size() > 5) {
            candidates = new ArrayList<Map<String, Object>>(candidates.subList(0, 5));
        }
        Map<String, Object> best = candidates.get(0);
        return map("success", true, "message", "compare generated", "session", map("id", id("session"), "status", "waitingConfirm", "query", query), "recommendation", map("intent", intent, "bestProduct", best, "best_product", best, "candidates", candidates, "reason", reason(best, fallback), "fallbackUsed", fallback, "fallback_used", fallback));
    }

    public Map<String, Object> selectionCommand(Map<String, Object> body) {
        String command = defaultText(body, "command", text(body, "text"));
        List<Map<String, Object>> candidates = extractCandidates(body);
        if (candidates.isEmpty()) {
            for (ProductEntity product : productRepository.findAllByOrderBySalesDescRatingDesc()) {
                candidates.add(productMap(product, 0));
            }
        }
        int index = Math.min(extractProductIndex(command), candidates.size() - 1);
        Map<String, Object> selected = candidates.get(Math.max(0, index));
        int quantity = extractQuantity(command);
        return map("success", true, "message", "selection parsed", "product", selected, "quantity", quantity, "session", map("id", id("session"), "status", "waitingPayment", "query", command, "selectedProductId", str(selected.get("id")), "selected_product_id", str(selected.get("id"))));
    }

    @Transactional
    public Map<String, Object> createPayment(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        String productId = text(body, "product_id");
        String addressId = text(body, "address_id");
        int quantity = intValue(body.get("quantity"), 1);
        String method = defaultText(body, "method", "password");
        String outcome = defaultText(body, "outcome", "success");
        ProductEntity product = product(productId);
        AddressEntity address = ownedAddress(addressId, elderlyId);
        double amount = product.price * quantity;
        String status = "cancelled".equals(outcome) ? "cancelled" : ("failed".equals(outcome) ? "failed" : "success");
        String message = "success".equals(status) ? "payment success" : ("cancelled".equals(status) ? "payment cancelled" : "payment failed");
        String orderId = null;
        if ("success".equals(status)) {
            OrderEntity order = new OrderEntity();
            order.id = id("order");
            order.elderlyAccountId = elderlyId;
            order.managedByChildAccountId = "child".equals(account.defaultRole) ? account.id : "";
            order.productId = product.id;
            order.productName = product.name;
            order.platform = product.platform;
            order.quantity = quantity;
            order.addressId = address.id;
            order.totalPrice = amount;
            order.paymentMethod = method;
            order.paymentStatus = status;
            order.createdAt = now();
            orderRepository.save(order);
            orderId = order.id;
            String childId = firstChildId(elderlyId);
            ReminderEntity reminder = new ReminderEntity();
            reminder.id = id("reminder");
            reminder.orderId = order.id;
            reminder.elderlyAccountId = elderlyId;
            reminder.childAccountId = childId;
            reminder.title = "老人购物提醒";
            reminder.content = address.receiver + " 在 " + product.platform + " 购买了 " + product.name + "，数量 " + quantity + "，金额 ¥" + String.format("%.2f", amount) + "。";
            reminder.readFlag = 0;
            reminder.createdAt = now();
            reminderRepository.save(reminder);
            NotificationEntity n = new NotificationEntity();
            n.id = id("notification");
            n.elderlyAccountId = elderlyId;
            n.childAccountId = childId;
            n.title = reminder.title;
            n.message = reminder.content;
            n.type = "payment";
            n.relatedId = order.id;
            n.read = "false";
            n.createdAt = now();
            notificationRepository.save(n);
        }
        PaymentRecordEntity paymentRecord = new PaymentRecordEntity();
        paymentRecord.id = id("pay-record");
        paymentRecord.orderId = orderId;
        paymentRecord.elderlyAccountId = elderlyId;
        paymentRecord.productId = productId;
        paymentRecord.amount = amount;
        paymentRecord.method = method;
        paymentRecord.status = status;
        paymentRecord.message = message;
        paymentRecord.createdAt = now();
        paymentRecordRepository.save(paymentRecord);
        audit(account.id, elderlyId, "payment." + status, message);
        return map("success", "success".equals(status), "payment_id", id("payment"), "order_id", orderId, "status", status, "message", message);
    }

    public Map<String, Object> listOrders(String authorization) {
        String elderlyId = currentElderlyId(currentAccount(authorization));
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (OrderEntity order : orderRepository.findByElderlyAccountIdOrderByCreatedAtDesc(elderlyId)) {
            ProductEntity product = productRepository.findById(order.productId).orElse(null);
            AddressEntity address = addressRepository.findById(order.addressId).orElse(null);
            Map<String, Object> row = orderMap(order);
            if (product != null) {
                row.put("shop_name", product.shopName);
                row.put("product_price", product.price);
                row.put("rating", product.rating);
                row.put("sales", product.sales);
                row.put("description", product.description);
                row.put("tags", product.tags);
            }
            row.put("address_receiver", address == null ? "" : address.receiver);
            row.put("address_phone", address == null ? "" : address.phone);
            row.put("address_detail", address == null ? "" : address.detail);
            rows.add(row);
        }
        return map("success", true, "orders", rows);
    }

    public Map<String, Object> listPaymentRecords(String authorization) {
        String elderlyId = currentElderlyId(currentAccount(authorization));
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (PaymentRecordEntity record : paymentRecordRepository.findByElderlyAccountIdOrderByCreatedAtDesc(elderlyId)) {
            rows.add(paymentRecordMap(record));
        }
        return map("success", true, "payment_records", rows);
    }

    public Map<String, Object> listReminders(String authorization) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (ReminderEntity reminder : reminderRepository.findByElderlyAccountIdOrChildAccountIdOrderByCreatedAtDesc(elderlyId, account.id)) {
            rows.add(reminderMap(reminder));
        }
        return map("success", true, "reminders", rows);
    }

    @Transactional
    public Map<String, Object> markRemindersRead(String authorization) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        List<ReminderEntity> reminders = reminderRepository.findByElderlyAccountIdOrChildAccountIdOrderByCreatedAtDesc(elderlyId, account.id);
        for (ReminderEntity reminder : reminders) {
            reminder.readFlag = 1;
            reminderRepository.save(reminder);
        }
        return listReminders(authorization);
    }

    public Map<String, Object> profileStats(String authorization) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        long orderCount = orderRepository.countByElderlyAccountId(elderlyId);
        int addressCount = addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId).size();
        List<ReminderEntity> reminders = reminderRepository.findByElderlyAccountIdOrChildAccountIdOrderByCreatedAtDesc(elderlyId, account.id);
        int unread = 0;
        for (ReminderEntity reminder : reminders) {
            if (reminder.readFlag == null || reminder.readFlag == 0) unread++;
        }
        int bindingCount = "child".equals(account.defaultRole) ? bindingRepository.findByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active").size() : bindingRepository.findByElderlyAccountIdAndStatus(elderlyId, "active").size();
        return map("success", true, "account", accountMap(account), "orderCount", orderCount, "order_count", orderCount, "addressCount", addressCount, "address_count", addressCount, "reminderCount", reminders.size(), "reminder_count", reminders.size(), "bindingCount", bindingCount, "binding_count", bindingCount, "unreadReminderCount", unread, "unread_reminder_count", unread);
    }

    public Map<String, Object> childDashboard(String authorization) {
        AccountEntity account = currentAccount(authorization);
        if (!"child".equals(account.defaultRole)) {
            return map("success", true, "addressCount", 0, "unreadReminderCount", 0, "bindingCount", 0, "defaultAddressText", "当前不是子女端", "latestReminderText", "暂无提醒");
        }
        String elderlyId = currentElderlyId(account);
        List<AddressEntity> addresses = addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId);
        List<ReminderEntity> reminders = reminderRepository.findByElderlyAccountIdOrChildAccountIdOrderByCreatedAtDesc(elderlyId, account.id);
        int unread = 0;
        for (ReminderEntity reminder : reminders) {
            if (reminder.readFlag == null || reminder.readFlag == 0) unread++;
        }
        AddressEntity first = addresses.isEmpty() ? null : addresses.get(0);
        return map("success", true, "addressCount", addresses.size(), "address_count", addresses.size(), "unreadReminderCount", unread, "unread_reminder_count", unread, "bindingCount", bindingRepository.findByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active").size(), "binding_count", bindingRepository.findByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active").size(), "defaultAddressText", first == null ? "暂无默认地址" : first.receiver + "，" + first.detail, "latestReminderText", reminders.isEmpty() ? "暂无提醒" : reminders.get(0).content);
    }

    public Map<String, Object> adminDashboard(String authorization) {
        AccountEntity account = currentAccount(authorization);
        if (!"admin".equals(account.defaultRole)) {
            return map("success", true, "totalAccounts", 0, "elderlyCount", 0, "childCount", 0, "csCount", 0, "totalOrders", 0, "pendingOrders", 0, "message", "当前不是管理员");
        }
        long totalAccounts = accountRepository.count();
        long orderCount = orderRepository.count();
        long pendingOrders = 0;
        for (OrderEntity o : orderRepository.findAll()) {
            if ("pending".equals(o.paymentStatus)) {
                pendingOrders++;
            }
        }
        int elderlyCount = 0;
        int childCount = 0;
        int csCount = 0;
        int adminCount = 0;
        for (AccountEntity a : accountRepository.findAll()) {
            if ("elderly".equals(a.defaultRole)) {
                elderlyCount++;
            } else if ("child".equals(a.defaultRole)) {
                childCount++;
            } else if ("customer_service".equals(a.defaultRole)) {
                csCount++;
            } else if ("admin".equals(a.defaultRole)) {
                adminCount++;
            }
        }
        return map("success", true, "totalAccounts", totalAccounts, "elderlyCount", elderlyCount, "childCount", childCount, "csCount", csCount, "adminCount", adminCount, "totalOrders", orderCount, "pendingOrders", pendingOrders);
    }

    public Map<String, Object> csDashboard(String authorization) {
        AccountEntity account = currentAccount(authorization);
        if (!"customer_service".equals(account.defaultRole)) {
            return map("success", true, "openTickets", 0, "resolvedToday", 0, "serviceGroup", "", "message", "当前不是客服");
        }
        CustomerServiceProfileEntity profile = csProfileRepository.findByAccountId(account.id).orElse(null);
        long openTickets = ticketRepository.findByStatusOrderByCreatedAtDesc("open").size() + ticketRepository.findByStatusOrderByCreatedAtDesc("processing").size();
        String today = now().substring(0, 10);
        long resolvedToday = ticketRepository.findByStatusOrderByCreatedAtDesc("resolved").stream()
            .filter((t) -> t.updatedAt != null && t.updatedAt.substring(0, 10).equals(today))
            .count();
        return map("success", true, "openTickets", openTickets, "resolvedToday", resolvedToday, "serviceGroup", profile != null ? profile.serviceGroup : "综合服务组");
    }

    public Map<String, Object> adminListAccounts(String authorization) {
        currentAccount(authorization);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (AccountEntity a : accountRepository.findAll()) {
            rows.add(accountMap(a));
        }
        return map("success", true, "accounts", rows);
    }

    @Transactional
    public Map<String, Object> adminCreateAccount(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        require("admin".equals(admin.defaultRole), HttpStatus.FORBIDDEN, "only admin can create account");
        String phone = text(body, "phone");
        String password = text(body, "password");
        String displayName = text(body, "display_name");
        String role = roleOrUnverified(text(body, "role"));
        require(phone.length() > 0 && password.length() > 0 && displayName.length() > 0, HttpStatus.BAD_REQUEST, "phone, password and display_name are required");
        require(!accountRepository.findByPhone(phone).isPresent(), HttpStatus.CONFLICT, "phone already registered");
        AccountEntity account = account(id("acct"), phone, encodePassword(password), displayName, role);
        accountRepository.save(account);
        ensureProfileForRole(account, role);
        audit(admin.id, null, "admin.create_account", "create account " + phone + " role=" + role);
        return map("success", true, "message", "account created", "account", accountMap(account));
    }

    @Transactional
    public Map<String, Object> adminUpdateAccount(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        require("admin".equals(admin.defaultRole), HttpStatus.FORBIDDEN, "only admin can update account");
        String accountId = text(body, "account_id");
        require(accountId.length() > 0, HttpStatus.BAD_REQUEST, "account_id is required");
        AccountEntity account = accountRepository.findById(accountId).orElse(null);
        require(account != null, HttpStatus.NOT_FOUND, "account not found");
        String phone = text(body, "phone");
        if (phone.length() > 0 && !phone.equals(account.phone)) {
            Optional<AccountEntity> existing = accountRepository.findByPhone(phone);
            require(!existing.isPresent() || existing.get().id.equals(accountId), HttpStatus.CONFLICT, "phone already used");
            account.phone = phone;
        }
        String displayName = text(body, "display_name");
        if (displayName.length() > 0) {
            account.displayName = displayName;
        }
        String role = text(body, "role");
        if (role.length() > 0 && roleOrUnverified(role).length() > 0 && !"unverified".equals(roleOrUnverified(role))) {
            account.defaultRole = roleOrUnverified(role);
            ensureProfileForRole(account, roleOrUnverified(role));
        }
        String status = text(body, "status");
        if (status.length() > 0) {
            account.status = status;
        }
        account.updatedAt = now();
        accountRepository.save(account);
        audit(admin.id, null, "admin.update_account", "update account " + accountId);
        return map("success", true, "message", "account updated", "account", accountMap(account));
    }

    @Transactional
    public Map<String, Object> adminSoftDeleteAccount(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        require("admin".equals(admin.defaultRole), HttpStatus.FORBIDDEN, "only admin can delete account");
        String accountId = text(body, "account_id");
        require(accountId.length() > 0, HttpStatus.BAD_REQUEST, "account_id is required");
        AccountEntity account = accountRepository.findById(accountId).orElse(null);
        require(account != null, HttpStatus.NOT_FOUND, "account not found");
        require(!"admin".equals(account.defaultRole), HttpStatus.FORBIDDEN, "cannot delete admin account");
        account.idUser = 1;
        account.status = "disabled";
        account.updatedAt = now();
        accountRepository.save(account);
        audit(admin.id, null, "admin.soft_delete_account", "soft delete account " + accountId);
        return map("success", true, "message", "account soft deleted", "account", accountMap(account));
    }

    @Transactional
    public Map<String, Object> adminRestoreAccount(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        require("admin".equals(admin.defaultRole), HttpStatus.FORBIDDEN, "only admin can restore account");
        String accountId = text(body, "account_id");
        require(accountId.length() > 0, HttpStatus.BAD_REQUEST, "account_id is required");
        AccountEntity account = accountRepository.findById(accountId).orElse(null);
        require(account != null, HttpStatus.NOT_FOUND, "account not found");
        account.idUser = 0;
        account.status = "active";
        account.updatedAt = now();
        accountRepository.save(account);
        audit(admin.id, null, "admin.restore_account", "restore account " + accountId);
        return map("success", true, "message", "account restored", "account", accountMap(account));
    }

    // === Admin: 用户列表 ===
    public Map<String, Object> adminListUsers(String authorization) {
        currentAccount(authorization);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (AccountEntity a : accountRepository.findAll()) {
            Map<String, Object> user = accountMap(a);
            user.put("orderCount", orderRepository.countByElderlyAccountId(a.id));
            rows.add(user);
        }
        return map("success", true, "users", rows, "total", rows.size());
    }

    // === Admin: 全平台订单列表 ===
    public Map<String, Object> adminListAllOrders(String authorization) {
        currentAccount(authorization);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (OrderEntity o : orderRepository.findAll()) {
            rows.add(orderMap(o));
        }
        return map("success", true, "orders", rows, "total", rows.size());
    }

    @Transactional
    public Map<String, Object> adminDeleteOrder(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        String orderId = text(body, "order_id");
        require(orderId.length() > 0, HttpStatus.BAD_REQUEST, "order_id is required");
        OrderEntity order = orderRepository.findById(orderId).orElse(null);
        require(order != null, HttpStatus.NOT_FOUND, "order not found");
        paymentRecordRepository.deleteByOrderId(orderId);
        orderRepository.deleteById(orderId);
        audit(admin.id, order.elderlyAccountId, "admin.order_delete", "delete order " + orderId + " product=" + order.productName);
        return map("success", true, "message", "order deleted");
    }

    @Transactional
    public Map<String, Object> adminClearAuditLogs(String authorization) {
        AccountEntity admin = currentAccount(authorization);
        auditLogRepository.deleteAll();
        audit(admin.id, admin.id, "admin.audit_clear", "clear all audit logs");
        return map("success", true, "message", "audit logs cleared");
    }

    @Transactional
    public Map<String, Object> adminDeleteAuditLog(String authorization, Map<String, Object> body) {
        AccountEntity admin = currentAccount(authorization);
        String logId = text(body, "log_id");
        require(logId.length() > 0, HttpStatus.BAD_REQUEST, "log_id is required");
        auditLogRepository.deleteById(logId);
        return map("success", true, "message", "audit log deleted");
    }

    public Map<String, Object> adminListAllAuditLogs(String authorization) {
        currentAccount(authorization);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (AuditLogEntity log : auditLogRepository.findAll()) {
            rows.add(map("id", log.id, "actor_account_id", log.actorAccountId, "elderly_account_id", log.elderlyAccountId, "action", log.action, "detail", log.detail, "created_at", log.createdAt));
        }
        return map("success", true, "logs", rows, "total", rows.size());
    }

    // === CS: 工单列表 (from database) ===
    public Map<String, Object> csListTickets(String authorization) {
        currentAccount(authorization);
        List<Map<String, Object>> tickets = new ArrayList<Map<String, Object>>();
        for (TicketEntity t : ticketRepository.findAllByOrderByCreatedAtDesc()) {
            tickets.add(ticketMap(t));
        }
        return map("success", true, "tickets", tickets);
    }

    @Transactional
    public Map<String, Object> csAssignTicket(String authorization, Map<String, Object> body) {
        AccountEntity cs = currentAccount(authorization);
        String ticketId = text(body, "ticket_id");
        require(ticketId.length() > 0, HttpStatus.BAD_REQUEST, "ticket_id is required");
        TicketEntity ticket = ticketRepository.findById(ticketId).orElse(null);
        require(ticket != null, HttpStatus.NOT_FOUND, "ticket not found");
        ticket.csAccountId = cs.id;
        ticket.status = "processing";
        ticket.updatedAt = now();
        ticketRepository.save(ticket);
        audit(cs.id, ticket.elderlyAccountId, "cs.ticket_assign", "assign ticket " + ticketId);
        return map("success", true, "message", "ticket assigned", "ticket", ticketMap(ticket));
    }

    @Transactional
    public Map<String, Object> csResolveTicket(String authorization, Map<String, Object> body) {
        AccountEntity cs = currentAccount(authorization);
        String ticketId = text(body, "ticket_id");
        String resolution = text(body, "resolution");
        require(ticketId.length() > 0, HttpStatus.BAD_REQUEST, "ticket_id is required");
        TicketEntity ticket = ticketRepository.findById(ticketId).orElse(null);
        require(ticket != null, HttpStatus.NOT_FOUND, "ticket not found");
        ticket.status = "resolved";
        if (resolution.length() > 0) {
            ticket.content = (ticket.content == null ? "" : ticket.content) + "\n\n解决结果：" + resolution;
        }
        ticket.updatedAt = now();
        ticketRepository.save(ticket);
        audit(cs.id, ticket.elderlyAccountId, "cs.ticket_resolve", "resolve ticket " + ticketId);
        return map("success", true, "message", "ticket resolved", "ticket", ticketMap(ticket));
    }

    @Transactional
    public Map<String, Object> csEscalateTicket(String authorization, Map<String, Object> body) {
        AccountEntity cs = currentAccount(authorization);
        String ticketId = text(body, "ticket_id");
        require(ticketId.length() > 0, HttpStatus.BAD_REQUEST, "ticket_id is required");
        TicketEntity ticket = ticketRepository.findById(ticketId).orElse(null);
        require(ticket != null, HttpStatus.NOT_FOUND, "ticket not found");
        ticket.priority = "urgent";
        ticket.updatedAt = now();
        ticketRepository.save(ticket);
        audit(cs.id, ticket.elderlyAccountId, "cs.ticket_escalate", "escalate ticket " + ticketId);
        return map("success", true, "message", "ticket escalated", "ticket", ticketMap(ticket));
    }

    public Map<String, Object> syncEvents(String authorization) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        List<Map<String, Object>> events = new ArrayList<Map<String, Object>>();
        for (SyncEventEntity e : syncEventRepository.findByElderlyAccountIdOrderByCreatedAtDesc(elderlyId)) {
            events.add(map("id", e.id, "elderly_account_id", e.elderlyAccountId, "type", e.type, "payload", e.payload != null ? e.payload : "", "created_at", e.createdAt));
        }
        return map("success", true, "events", events);
    }

    public Map<String, Object> notifications(String authorization) {
        AccountEntity account = currentAccount(authorization);
        List<Map<String, Object>> notifs = new ArrayList<Map<String, Object>>();
        for (NotificationEntity n : notificationRepository.findByElderlyAccountIdOrderByCreatedAtDesc(account.id)) {
            notifs.add(map("id", n.id, "elderly_account_id", n.elderlyAccountId, "child_account_id", n.childAccountId, "title", n.title, "message", n.message != null ? n.message : "", "type", n.type, "related_id", n.relatedId != null ? n.relatedId : "", "read", n.read, "created_at", n.createdAt));
        }
        return map("success", true, "notifications", notifs);
    }

    public Map<String, Object> auditLogs(String authorization) {
        AccountEntity account = currentAccount(authorization);
        String elderlyId = currentElderlyId(account);
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (AuditLogEntity log : auditLogRepository.findByElderlyAccountIdOrActorAccountIdOrderByCreatedAtDesc(elderlyId, account.id)) {
            rows.add(map("id", log.id, "actor_account_id", log.actorAccountId, "elderly_account_id", log.elderlyAccountId, "action", log.action, "detail", log.detail, "created_at", log.createdAt));
        }
        return map("success", true, "logs", rows);
    }

    private void seedProducts() {
        productRepository.save(product("shoe-001", "京东", "轻便软底老人健步鞋", 189, 4.8, 23500, "安心步行旗舰店", "软底防滑，鞋面透气，适合日常散步。", "鞋,不累脚,防滑,老人", "shoe", "https://images.unsplash.com/photo-1542291026-7eec264c27ff"));
        productRepository.save(product("shoe-002", "淘宝", "防滑透气中老年运动鞋", 159, 4.6, 18200, "舒步生活馆", "加宽鞋楦，脚背不压迫，适合久走。", "鞋,透气,宽松,不累脚", "shoe", "https://images.unsplash.com/photo-1549298916-b41d501d3772"));
        productRepository.save(product("shoe-003", "拼多多", "软弹减震老人休闲鞋", 129, 4.5, 31000, "惠民鞋业", "价格实惠，软弹鞋底，防滑纹路清晰。", "鞋,减震,防滑,老人", "shoe", "https://images.unsplash.com/photo-1560769629-975ec94e6a86"));
        productRepository.save(product("milk-001", "京东", "高钙无糖中老年奶粉", 168, 4.8, 28400, "营养生活旗舰店", "无蔗糖配方，添加钙和维生素D。", "奶粉,高钙,无糖,中老年", "milk", "https://images.unsplash.com/photo-1550583724-b2692b85b150"));
        productRepository.save(product("phone-001", "京东", "大按键老人手机", 299, 4.7, 12800, "银发数码", "大字体、大音量、长续航，支持一键拨号。", "手机,老人,大按键,长续航", "phone", "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9"));
        productRepository.save(product("bp-001", "京东", "家用上臂式血压计", 229, 4.8, 31000, "康养医疗器械", "大屏显示，语音播报，适合老人居家测量。", "血压计,上臂式,语音,老人", "blood-pressure", "https://images.unsplash.com/photo-1588776814546-1ffcf47267a5"));
        productRepository.save(product("rice-001", "拼多多", "东北长粒香大米 10斤", 49.9, 4.8, 58000, "粮油优选", "米香浓郁，家庭日常囤货。", "大米,粮油,家庭,常买", "rice", "https://images.unsplash.com/photo-1586201375761-83865001e31c"));
        productRepository.save(product("paper-001", "淘宝", "柔韧抽纸家庭装", 39.9, 4.7, 69000, "家清用品", "家庭常备，柔韧不易破。", "抽纸,家庭装,日用,常买", "paper", "https://images.unsplash.com/photo-1584556812952-905ffd0c611a"));
    }

    private AccountEntity currentAccount(String authorization) {
        String token = jwtTokenService.resolveToken(authorization);
        if (token == null || token.length() == 0) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing bearer token");
        if (!jwtTokenService.isTokenValid(token)) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid token");
        String accountId = jwtTokenService.extractAccountId(token);
        if (accountId == null || accountId.length() == 0) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid token");
        return accountRepository.findById(accountId).orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Account unavailable"));
    }

    private String currentElderlyId(AccountEntity account) {
        if ("elderly".equals(account.defaultRole)) return account.id;
        if ("admin".equals(account.defaultRole) || "customer_service".equals(account.defaultRole)) {
            Optional<FamilyBindingEntity> firstBinding = bindingRepository.findFirstByStatusOrderByCreatedAtDesc("active");
            return firstBinding.isPresent() ? firstBinding.get().elderlyAccountId : "";
        }
        Optional<FamilyBindingEntity> binding = bindingRepository.findFirstByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active");
        if (binding.isPresent()) return binding.get().elderlyAccountId;
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Child account is not bound");
    }

    private AccountEntity findElderly(String keyword) {
        for (AccountEntity account : accountRepository.findAll()) {
            if ("elderly".equals(account.defaultRole) && (account.phone.equals(keyword) || bindingCodeFor(account).equals(keyword))) return account;
        }
        return null;
    }

    private String bindingCodeFor(AccountEntity elderly) {
        FamilyBindingEntity existing = bindingRepository.findByElderlyAccountIdAndStatus(elderly.id, "active").stream().findFirst().orElse(null);
        if (existing != null && existing.bindingCode != null && existing.bindingCode.length() > 0) {
            return existing.bindingCode;
        }
        String phone = elderly.phone == null ? "" : elderly.phone;
        return "HS" + phone.substring(Math.max(0, phone.length() - 4));
    }

    private AddressEntity ownedAddress(String addressId, String elderlyId) {
        AddressEntity address = addressRepository.findById(addressId).orElse(null);
        require(address != null && elderlyId.equals(address.elderlyAccountId), HttpStatus.NOT_FOUND, "address not found");
        return address;
    }

    private ProductEntity product(String id) {
        return productRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "product not found"));
    }

    private String firstChildId(String elderlyId) {
        List<FamilyBindingEntity> bindings = bindingRepository.findByElderlyAccountIdAndStatus(elderlyId, "active");
        return bindings.isEmpty() ? "" : bindings.get(0).childAccountId;
    }

    private List<Map<String, Object>> addressMaps(String elderlyId) {
        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();
        for (AddressEntity address : addressRepository.findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(elderlyId)) rows.add(addressMap(address));
        return rows;
    }

    private List<ProductEntity> searchProducts(Map<String, Object> intent) {
        String product = str(intent.get("product"));
        String alias = alias(product);
        List<ProductEntity> matched = new ArrayList<ProductEntity>();
        for (ProductEntity item : productRepository.findAllByOrderBySalesDescRatingDesc()) {
            String haystack = (item.name + "," + item.description + "," + item.tags + "," + item.imageKey).toLowerCase();
            if ("日用品".equals(product) || haystack.contains(product.toLowerCase()) || haystack.contains(alias)) matched.add(item);
        }
        return matched;
    }

    private Map<String, Object> parseIntent(String query) {
        String product = "日用品";
        String lower = query.toLowerCase();
        if (containsAny(lower, "鞋", "不累脚", "shoe")) product = "鞋";
        else if (containsAny(lower, "奶粉", "无糖", "高钙", "milk")) product = "奶粉";
        else if (containsAny(lower, "手机", "大按键", "phone")) product = "手机";
        else if (containsAny(lower, "血压")) product = "血压计";
        List<String> attrs = new ArrayList<String>();
        for (String attr : Arrays.asList("无糖", "高钙", "防滑", "不累脚", "透气", "大按键", "大音量", "语音", "安全", "恒温")) if (query.contains(attr)) attrs.add(attr);
        return map("product", product, "attributes", attrs, "quantity", extractQuantity(query), "rawText", query, "raw_text", query);
    }

    private double score(ProductEntity product) {
        return Math.round((product.rating * 18 + Math.min(30, product.sales / 1800.0) + Math.max(0, 20 - product.price / 20.0)) * 10) / 10.0;
    }

    private String reason(Map<String, Object> product, boolean fallback) {
        return (fallback ? "未精确识别商品，已按相近需求推荐。" : "") + str(product.get("name")) + " 综合评分较高，销量 " + intValue(product.get("sales"), 0) + "，价格 ¥" + String.format("%.2f", num(product.get("price"))) + "。";
    }

    private Map<String, Object> authResponse(AccountEntity account) {
        String token = jwtTokenService.generateToken(account);
        return map("success", true, "access_token", token, "token_type", "Bearer", "account", accountMap(account));
    }

    private void audit(String actorId, String elderlyId, String action, String detail) {
        AuditLogEntity log = new AuditLogEntity();
        log.id = id("audit");
        log.actorAccountId = actorId;
        log.elderlyAccountId = elderlyId;
        log.action = action;
        log.detail = detail;
        log.createdAt = now();
        auditLogRepository.save(log);
    }

    private void sync(String elderlyId, String type, String payload) {
        SyncEventEntity e = new SyncEventEntity();
        e.id = id("sync");
        e.elderlyAccountId = elderlyId;
        e.type = type;
        e.payload = payload;
        e.createdAt = now();
        syncEventRepository.save(e);
    }

    private String encodePassword(String rawPassword) {
        return passwordEncoder.encode(rawPassword);
    }

    private boolean passwordMatches(String rawPassword, String storedPassword) {
        if (storedPassword == null || storedPassword.length() == 0) {
            return false;
        }
        if (isEncodedPassword(storedPassword)) {
            return passwordEncoder.matches(rawPassword, storedPassword);
        }
        return rawPassword.equals(storedPassword);
    }

    private void upgradePasswordIfNeeded(AccountEntity account, String rawPassword) {
        if (account != null && account.password != null && !isEncodedPassword(account.password) && rawPassword.equals(account.password)) {
            account.password = encodePassword(rawPassword);
            account.updatedAt = now();
            accountRepository.save(account);
        }
    }

    private boolean needsPasswordUpgrade(String storedPassword) {
        return storedPassword != null && storedPassword.length() > 0 && !isEncodedPassword(storedPassword);
    }

    private boolean isEncodedPassword(String storedPassword) {
        if (storedPassword == null) {
            return false;
        }
        return storedPassword.startsWith("$2a$") || storedPassword.startsWith("$2b$") || storedPassword.startsWith("$2y$");
    }

    private AccountEntity account(String id, String phone, String password, String name, String role) {
        AccountEntity account = new AccountEntity();
        account.id = id;
        account.idUser = 0;
        account.phone = phone;
        account.password = isEncodedPassword(password) ? password : encodePassword(password);
        account.displayName = name;
        account.defaultRole = role;
        account.status = "active";
        account.huaweiOpenId = "";
        account.huaweiUnionId = "";
        account.createdAt = now();
        account.updatedAt = now();
        return account;
    }

    private FamilyBindingEntity binding(String id, String elderlyId, String childId, String code) {
        FamilyBindingEntity binding = new FamilyBindingEntity();
        binding.id = id;
        binding.elderlyAccountId = elderlyId;
        binding.childAccountId = childId;
        binding.bindingCode = code;
        binding.status = "active";
        binding.createdAt = now();
        binding.updatedAt = now();
        return binding;
    }

    private AddressEntity address(String id, String elderlyId, String childId, String receiver, String phone, String detail, int isDefault) {
        AddressEntity address = new AddressEntity();
        address.id = id;
        address.elderlyAccountId = elderlyId;
        address.managedByChildAccountId = childId;
        address.receiver = receiver;
        address.phone = phone;
        address.detail = detail;
        address.isDefault = isDefault;
        address.createdAt = now();
        address.updatedAt = now();
        return address;
    }

    private ProductEntity product(String id, String platform, String name, double price, double rating, int sales, String shopName, String description, String tags, String imageKey, String imageUrl) {
        ProductEntity product = new ProductEntity();
        product.id = id;
        product.platform = platform;
        product.name = name;
        product.price = price;
        product.rating = rating;
        product.sales = sales;
        product.shopName = shopName;
        product.description = description;
        product.tags = tags;
        product.imageKey = imageKey;
        product.imageUrl = imageUrl;
        return product;
    }

    private ElderlyProfileEntity elderlyProfile(String id, String accountId, String realName, int age, int careModeEnabled, String emergencyPhone, String bindingCode) {
        ElderlyProfileEntity profile = new ElderlyProfileEntity();
        profile.id = id;
        profile.accountId = accountId;
        profile.realName = realName;
        profile.age = age;
        profile.careModeEnabled = careModeEnabled;
        profile.emergencyPhone = emergencyPhone;
        profile.bindingCode = bindingCode;
        profile.createdAt = now();
        profile.updatedAt = now();
        return profile;
    }

    private AdminProfileEntity adminProfile(String id, String accountId, String realName, String department, String permissions) {
        AdminProfileEntity profile = new AdminProfileEntity();
        profile.id = id;
        profile.accountId = accountId;
        profile.realName = realName;
        profile.department = department;
        profile.permissions = permissions;
        profile.createdAt = now();
        profile.updatedAt = now();
        return profile;
    }

    private CustomerServiceProfileEntity csProfile(String id, String accountId, String realName, String serviceGroup, int maxConcurrent, String status) {
        CustomerServiceProfileEntity profile = new CustomerServiceProfileEntity();
        profile.id = id;
        profile.accountId = accountId;
        profile.realName = realName;
        profile.serviceGroup = serviceGroup;
        profile.maxConcurrent = maxConcurrent;
        profile.status = status;
        profile.createdAt = now();
        profile.updatedAt = now();
        return profile;
    }

    private void ensureProfileForRole(AccountEntity account, String role) {
        if ("admin".equals(role) && !adminProfileRepository.findByAccountId(account.id).isPresent()) {
            adminProfileRepository.save(adminProfile(id("admin-profile"), account.id, account.displayName, "运营管理部", "account_manage,audit_view,system_config"));
        }
        if ("customer_service".equals(role) && !csProfileRepository.findByAccountId(account.id).isPresent()) {
            csProfileRepository.save(csProfile(id("cs-profile"), account.id, account.displayName, "综合服务组", 10, "active"));
        }
    }

    private ChildProfileEntity childProfile(String id, String accountId, String realName, String relation, int notificationEnabled) {
        ChildProfileEntity profile = new ChildProfileEntity();
        profile.id = id;
        profile.accountId = accountId;
        profile.realName = realName;
        profile.relation = relation;
        profile.notificationEnabled = notificationEnabled;
        profile.createdAt = now();
        profile.updatedAt = now();
        return profile;
    }

    private Map<String, Object> accountMap(AccountEntity a) {
        String phone = isPhoneMissing(a.phone) ? "" : a.phone;
        return map("id", a.id, "id_user", a.idUser, "phone", phone, "password_hash", "", "display_name", a.displayName, "default_role", a.defaultRole, "status", a.status, "nick_name", a.nickName == null ? "" : a.nickName, "avatar_uri", a.avatarUri == null ? "" : a.avatarUri, "huawei_open_id", a.huaweiOpenId == null ? "" : a.huaweiOpenId, "huawei_union_id", a.huaweiUnionId == null ? "" : a.huaweiUnionId, "created_at", a.createdAt, "updated_at", a.updatedAt);
    }

    private boolean isPhoneMissing(String phone) {
        return phone == null || phone.length() == 0 || phone.startsWith("HW_PENDING_") || phone.startsWith("HWP_");
    }

    private String huaweiPlaceholderPhone(String openId) {
        String basis = openId == null || openId.trim().length() == 0 ? id("hw") : openId.trim();
        return "HWP_" + shortHexDigest(basis, 16);
    }

    private String shortHexDigest(String value, int length) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte item : bytes) {
                hex.append(String.format("%02x", item));
            }
            if (hex.length() >= length) {
                return hex.substring(0, length).toUpperCase();
            }
            while (hex.length() < length) {
                hex.append('0');
            }
            return hex.toString().toUpperCase();
        } catch (NoSuchAlgorithmException error) {
            String fallback = value.replaceAll("[^A-Za-z0-9]", "").toUpperCase();
            if (fallback.length() >= length) {
                return fallback.substring(0, length);
            }
            StringBuilder padded = new StringBuilder(fallback);
            while (padded.length() < length) {
                padded.append('0');
            }
            return padded.toString();
        }
    }

    private Map<String, Object> bindingMap(FamilyBindingEntity b) {
        return map("id", b.id, "elderly_account_id", b.elderlyAccountId, "child_account_id", b.childAccountId, "binding_code", b.bindingCode, "status", b.status, "created_at", b.createdAt, "updated_at", b.updatedAt);
    }

    private Map<String, Object> addressMap(AddressEntity a) {
        return map("id", a.id, "elderly_account_id", a.elderlyAccountId, "managed_by_child_account_id", a.managedByChildAccountId, "receiver", a.receiver, "phone", a.phone, "detail", a.detail, "is_default", a.isDefault, "created_at", a.createdAt, "updated_at", a.updatedAt);
    }

    private Map<String, Object> productMap(ProductEntity p, double score) {
        double finalScore = p.recommendScore != null && p.recommendScore > 0 ? p.recommendScore : score;
        return map("id", p.id, "platform", p.platform, "name", p.name, "price", p.price, "rating", p.rating, "sales", p.sales, "shop_name", p.shopName, "shopName", p.shopName, "description", p.description, "tags", p.tags, "tag_list", Arrays.asList(p.tags == null ? "" : p.tags.split(",")), "recommend_score", finalScore, "recommendScore", finalScore, "image_key", p.imageKey, "imageKey", p.imageKey, "image_url", p.imageUrl, "imageUrl", p.imageUrl);
    }

    private Map<String, Object> orderMap(OrderEntity o) {
        return map("id", o.id, "elderly_account_id", o.elderlyAccountId, "managed_by_child_account_id", o.managedByChildAccountId, "product_id", o.productId, "product_name", o.productName, "platform", o.platform, "quantity", o.quantity, "address_id", o.addressId, "total_price", o.totalPrice, "payment_method", o.paymentMethod, "payment_status", o.paymentStatus, "created_at", o.createdAt);
    }

    private Map<String, Object> reminderMap(ReminderEntity r) {
        return map("id", r.id, "order_id", r.orderId, "elderly_account_id", r.elderlyAccountId, "child_account_id", r.childAccountId, "title", r.title, "content", r.content, "read", r.readFlag == null ? 0 : r.readFlag, "created_at", r.createdAt);
    }

    private Map<String, Object> paymentRecordMap(PaymentRecordEntity r) {
        return map("id", r.id, "order_id", r.orderId, "elderly_account_id", r.elderlyAccountId, "product_id", r.productId, "amount", r.amount, "method", r.method, "status", r.status, "message", r.message, "created_at", r.createdAt);
    }

    private Map<String, Object> ticketMap(TicketEntity t) {
        String elderlyName = "";
        if (t.elderlyAccountId != null && t.elderlyAccountId.length() > 0) {
            AccountEntity elderly = accountRepository.findById(t.elderlyAccountId).orElse(null);
            elderlyName = elderly != null ? elderly.displayName : "";
        }
        String statusCn = "open".equals(t.status) ? "待处理" : ("processing".equals(t.status) ? "处理中" : ("resolved".equals(t.status) ? "已处理" : t.status));
        String priorityCn = "urgent".equals(t.priority) ? "紧急" : ("high".equals(t.priority) ? "高" : "普通");
        return map("id", t.id, "user", elderlyName, "title", t.title, "priority", priorityCn, "status", statusCn, "time", t.createdAt, "elderly_account_id", t.elderlyAccountId != null ? t.elderlyAccountId : "", "cs_account_id", t.csAccountId != null ? t.csAccountId : "", "content", t.content != null ? t.content : "", "created_at", t.createdAt, "updated_at", t.updatedAt);
    }

    private void seedTickets() {
        ticketRepository.save(ticket("ticket-001", "", "acct-elderly-001", "", "老人咨询订单状态", "徐叔叔想知道血压计的物流进度", "open", "normal"));
        ticketRepository.save(ticket("ticket-002", "", "acct-elderly-001", "", "支付失败求助", "子女帮老人支付的订单显示失败但已扣款", "open", "urgent"));
        ticketRepository.save(ticket("ticket-003", "", "acct-elderly-001", "", "收货地址修改请求", "老人不会操作修改地址，需要协助添加新地址", "open", "normal"));
        ticketRepository.save(ticket("ticket-004", "", "acct-elderly-001", "", "退换货流程咨询", "咨询血压计退换货流程", "resolved", "normal"));
    }

    private TicketEntity ticket(String id, String csAccountId, String elderlyAccountId, String orderId, String title, String content, String status, String priority) {
        TicketEntity t = new TicketEntity();
        t.id = id;
        t.csAccountId = csAccountId;
        t.elderlyAccountId = elderlyAccountId;
        t.orderId = orderId;
        t.title = title;
        t.content = content;
        t.status = status;
        t.priority = priority;
        t.createdAt = now();
        t.updatedAt = now();
        return t;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> extractCandidates(Map<String, Object> body) {
        Object raw = body.get("candidates");
        List<Map<String, Object>> result = new ArrayList<Map<String, Object>>();
        if (raw instanceof List) for (Object item : (List<Object>) raw) if (item instanceof Map) result.add((Map<String, Object>) item);
        return result;
    }

    private static Map<String, Object> map(Object... pairs) {
        Map<String, Object> result = new LinkedHashMap<String, Object>();
        for (int i = 0; i + 1 < pairs.length; i += 2) result.put(String.valueOf(pairs[i]), pairs[i + 1]);
        return result;
    }

    private static void require(boolean condition, HttpStatus status, String message) {
        if (!condition) throw new ResponseStatusException(status, message);
    }

    private static String now() {
        return LocalDateTime.now().format(TIME_FORMATTER);
    }

    private static String id(String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    private static String text(Map<String, Object> body, String key) {
        Object value = body == null ? null : body.get(key);
        return value == null ? "" : String.valueOf(value).trim();
    }

    private static String defaultText(Map<String, Object> body, String key, String fallback) {
        String value = text(body, key);
        return value.length() == 0 ? fallback : value;
    }

    private static String roleOrUnverified(String role) {
        return "elderly".equals(role) || "child".equals(role) || "admin".equals(role) || "customer_service".equals(role) ? role : "unverified";
    }

    private static String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    private static int intValue(Object value, int fallback) {
        if (value instanceof Number) return ((Number) value).intValue();
        try { return Integer.parseInt(str(value)); } catch (Exception ignored) { return fallback; }
    }

    private static double num(Object value) {
        if (value instanceof Number) return ((Number) value).doubleValue();
        try { return Double.parseDouble(str(value)); } catch (Exception ignored) { return 0.0; }
    }

    private static boolean containsAny(String text, String... words) {
        for (String word : words) if (text.contains(word)) return true;
        return false;
    }

    private static String alias(String product) {
        if ("鞋".equals(product)) return "shoe";
        if ("奶粉".equals(product)) return "milk";
        if ("手机".equals(product)) return "phone";
        if ("血压计".equals(product)) return "blood-pressure";
        return product.toLowerCase();
    }

    private static int extractProductIndex(String text) {
        if (containsAny(text, "第三", "第3", "3")) return 2;
        if (containsAny(text, "第二", "第2", "2")) return 1;
        return 0;
    }

    @Transactional
    public Map<String, Object> updateProfile(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String realName = text(body, "real_name");
        String ageStr = text(body, "age");
        String emergencyPhone = text(body, "emergency_phone");
        String relation = text(body, "relation");
        String nickName = text(body, "nick_name");
        String displayName = text(body, "display_name");

        if (nickName.length() > 0) {
            account.nickName = nickName;
        }
        if (displayName.length() > 0) {
            account.displayName = displayName;
        }
        account.updatedAt = now();
        accountRepository.save(account);

        if ("elderly".equals(account.defaultRole)) {
            ElderlyProfileEntity profile = elderlyProfileRepository.findByAccountId(account.id).orElse(null);
            if (profile != null) {
                if (realName.length() > 0) profile.realName = realName;
                if (ageStr.length() > 0) profile.age = intValue(body.get("age"), profile.age);
                if (emergencyPhone.length() > 0) profile.emergencyPhone = emergencyPhone;
                profile.updatedAt = now();
                elderlyProfileRepository.save(profile);
            }
        } else if ("child".equals(account.defaultRole)) {
            ChildProfileEntity profile = childProfileRepository.findByAccountId(account.id).orElse(null);
            if (profile != null) {
                if (realName.length() > 0) profile.realName = realName;
                if (relation.length() > 0) profile.relation = relation;
                profile.updatedAt = now();
                childProfileRepository.save(profile);
            }
        }

        audit(account.id, null, "profile.update", "updated profile fields");
        return map("success", true, "message", "个人资料更新成功");
    }

    @Transactional
    public Map<String, Object> submitFeedback(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String title = text(body, "title");
        String content = text(body, "content");
        String priority = defaultText(body, "priority", "normal");
        require(title.length() > 0, HttpStatus.BAD_REQUEST, "title is required");
        require(content.length() > 0, HttpStatus.BAD_REQUEST, "content is required");
        String elderlyAccountId = "";
        if ("elderly".equals(account.defaultRole)) {
            elderlyAccountId = account.id;
        } else if ("child".equals(account.defaultRole)) {
            Optional<FamilyBindingEntity> binding = bindingRepository.findFirstByChildAccountIdAndStatusOrderByCreatedAtDesc(account.id, "active");
            elderlyAccountId = binding.isPresent() ? binding.get().elderlyAccountId : "";
        }
        TicketEntity ticket = new TicketEntity();
        ticket.id = id("ticket");
        ticket.csAccountId = "";
        ticket.elderlyAccountId = elderlyAccountId;
        ticket.orderId = "";
        ticket.title = title;
        ticket.content = content;
        ticket.status = "open";
        ticket.priority = priority;
        ticket.createdAt = now();
        ticket.updatedAt = now();
        ticketRepository.save(ticket);
        audit(account.id, elderlyAccountId.length() > 0 ? elderlyAccountId : null, "feedback.submit", "submit feedback: " + title);
        return map("success", true, "message", "反馈已提交，客服将尽快处理", "ticket", ticketMap(ticket));
    }

    public Map<String, Object> huaweiPreOrder(String authorization, Map<String, Object> body) {
        AccountEntity account = currentAccount(authorization);
        String productName = text(body, "product_name");
        double amount = num(body.get("amount"));
        String mercOrderNo = text(body, "merc_order_no");
        String callbackUrl = text(body, "callback_url");
        require(productName.length() > 0, HttpStatus.BAD_REQUEST, "product_name is required");
        require(amount > 0, HttpStatus.BAD_REQUEST, "amount must be positive");
        String prepayId = id("prepay");
        String timestamp = String.valueOf(System.currentTimeMillis());
        String noncestr = id("nonce");
        String sign = "mock_sign_" + prepayId;
        String orderStr = "{\"app_id\":\"1992956668018718912\",\"merc_no\":\"300000000000000\",\"prepay_id\":\"" + prepayId +
                "\",\"timestamp\":\"" + timestamp + "\",\"noncestr\":\"" + noncestr +
                "\",\"sign\":\"" + sign + "\",\"auth_id\":\"auth_demo_001\"}";
        audit(account.id, null, "payment.huawei_preorder", "huawei pre-order for " + productName + " amount=" + amount);
        return map("success", true, "message", "pre-order created", "order_str", orderStr, "prepay_id", prepayId);
    }

    private static int extractQuantity(String text) {
        if (containsAny(text, "十", "10")) return 10;
        if (containsAny(text, "九", "9")) return 9;
        if (containsAny(text, "八", "8")) return 8;
        if (containsAny(text, "七", "7")) return 7;
        if (containsAny(text, "六", "6")) return 6;
        if (containsAny(text, "五", "5")) return 5;
        if (containsAny(text, "四", "4")) return 4;
        if (containsAny(text, "三", "3")) return 3;
        if (containsAny(text, "两", "二", "2")) return 2;
        return 1;
    }
}
