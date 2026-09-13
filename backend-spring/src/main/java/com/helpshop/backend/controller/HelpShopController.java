package com.helpshop.backend.controller;

import com.helpshop.backend.service.HelpShopService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HelpShopController {
    private final HelpShopService service;

    public HelpShopController(HelpShopService service) {
        this.service = service;
    }

    @GetMapping("/")
    public Map<String, Object> index() {
        return service.index();
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return service.health();
    }

    @PostMapping("/api/auth/sms/send")
    public Map<String, Object> sendSmsCode(@RequestBody Map<String, Object> body) {
        return service.sendSmsCode(body);
    }

    @PostMapping("/api/auth/register")
    public Map<String, Object> register(@RequestBody Map<String, Object> body) {
        return service.register(body);
    }

    @PostMapping("/api/auth/login")
    public Map<String, Object> login(@RequestBody Map<String, Object> body) {
        return service.login(body);
    }

    @GetMapping("/api/auth/me")
    public Map<String, Object> me(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.me(authorization);
    }

    @PostMapping("/api/auth/certify")
    public Map<String, Object> certify(@RequestHeader(value = "Authorization", required = false) String authorization,
                                       @RequestBody Map<String, Object> body) {
        return service.certify(authorization, body);
    }

    @PostMapping("/api/auth/huawei-login")
    public Map<String, Object> huaweiLogin(@RequestBody Map<String, Object> body) {
        return service.huaweiLogin(body);
    }

    @PostMapping("/api/auth/link-phone")
    public Map<String, Object> linkPhone(@RequestHeader(value = "Authorization", required = false) String authorization,
                                         @RequestBody Map<String, Object> body) {
        return service.linkPhone(authorization, body);
    }

    @PostMapping("/api/family/bind")
    public Map<String, Object> bindFamily(@RequestHeader(value = "Authorization", required = false) String authorization,
                                          @RequestBody Map<String, Object> body) {
        return service.bindFamily(authorization, body);
    }

    @GetMapping("/api/family/bindings")
    public Map<String, Object> listFamilyBindings(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.listFamilyBindings(authorization);
    }

    @GetMapping("/api/addresses")
    public Map<String, Object> listAddresses(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.listAddresses(authorization);
    }

    @PostMapping("/api/addresses")
    public Map<String, Object> createAddress(@RequestHeader(value = "Authorization", required = false) String authorization,
                                             @RequestBody Map<String, Object> body) {
        return service.createAddress(authorization, body);
    }

    @PostMapping("/api/addresses/default")
    public Map<String, Object> setDefaultAddress(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                 @RequestBody Map<String, Object> body) {
        return service.setDefaultAddress(authorization, body);
    }

    @PostMapping("/api/addresses/delete")
    public Map<String, Object> deleteAddress(@RequestHeader(value = "Authorization", required = false) String authorization,
                                             @RequestBody Map<String, Object> body) {
        return service.deleteAddress(authorization, body);
    }

    @GetMapping("/api/products/mock")
    public Map<String, Object> listProducts() {
        return service.listProducts();
    }

    @GetMapping("/api/products/{id}")
    public Map<String, Object> productDetail(@PathVariable("id") String id) {
        return service.productDetail(id);
    }

    @PostMapping("/api/agent/compare")
    public Map<String, Object> compare(@RequestBody Map<String, Object> body) {
        return service.compare(body);
    }

    @PostMapping("/api/agent/selection-command")
    public Map<String, Object> selectionCommand(@RequestBody Map<String, Object> body) {
        return service.selectionCommand(body);
    }

    @PostMapping("/api/payments/mock")
    public Map<String, Object> createPayment(@RequestHeader(value = "Authorization", required = false) String authorization,
                                             @RequestBody Map<String, Object> body) {
        return service.createPayment(authorization, body);
    }

    @PostMapping("/api/payments/huawei/preorder")
    public Map<String, Object> huaweiPreOrder(@RequestHeader(value = "Authorization", required = false) String authorization,
                                              @RequestBody Map<String, Object> body) {
        return service.huaweiPreOrder(authorization, body);
    }

    @GetMapping("/api/orders")
    public Map<String, Object> listOrders(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.listOrders(authorization);
    }

    @GetMapping("/api/payment-records")
    public Map<String, Object> listPaymentRecords(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.listPaymentRecords(authorization);
    }

    @GetMapping("/api/reminders")
    public Map<String, Object> listReminders(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.listReminders(authorization);
    }

    @PostMapping("/api/reminders/read-all")
    public Map<String, Object> markRemindersRead(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.markRemindersRead(authorization);
    }

    @GetMapping("/api/profile/stats")
    public Map<String, Object> profileStats(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.profileStats(authorization);
    }

    @GetMapping("/api/child/dashboard")
    public Map<String, Object> childDashboard(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.childDashboard(authorization);
    }

    @GetMapping("/api/admin/dashboard")
    public Map<String, Object> adminDashboard(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminDashboard(authorization);
    }

    @GetMapping("/api/admin/users")
    public Map<String, Object> adminListUsers(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminListUsers(authorization);
    }

    @GetMapping("/api/admin/orders")
    public Map<String, Object> adminListAllOrders(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminListAllOrders(authorization);
    }

    @PostMapping("/api/admin/orders/delete")
    public Map<String, Object> adminDeleteOrder(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                  @RequestBody Map<String, Object> body) {
        return service.adminDeleteOrder(authorization, body);
    }

    @PostMapping("/api/admin/audit-logs/clear")
    public Map<String, Object> adminClearAuditLogs(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminClearAuditLogs(authorization);
    }

    @PostMapping("/api/admin/audit-logs/delete")
    public Map<String, Object> adminDeleteAuditLog(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                     @RequestBody Map<String, Object> body) {
        return service.adminDeleteAuditLog(authorization, body);
    }

    @GetMapping("/api/admin/audit-logs")
    public Map<String, Object> adminListAllAuditLogs(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminListAllAuditLogs(authorization);
    }

    @GetMapping("/api/cs/dashboard")
    public Map<String, Object> csDashboard(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.csDashboard(authorization);
    }

    @GetMapping("/api/cs/tickets")
    public Map<String, Object> csListTickets(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.csListTickets(authorization);
    }

    @PostMapping("/api/cs/tickets/assign")
    public Map<String, Object> csAssignTicket(@RequestHeader(value = "Authorization", required = false) String authorization,
                                               @RequestBody Map<String, Object> body) {
        return service.csAssignTicket(authorization, body);
    }

    @PostMapping("/api/cs/tickets/resolve")
    public Map<String, Object> csResolveTicket(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                @RequestBody Map<String, Object> body) {
        return service.csResolveTicket(authorization, body);
    }

    @PostMapping("/api/cs/tickets/escalate")
    public Map<String, Object> csEscalateTicket(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                 @RequestBody Map<String, Object> body) {
        return service.csEscalateTicket(authorization, body);
    }

    @GetMapping("/api/sync/events")
    public Map<String, Object> syncEvents(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.syncEvents(authorization);
    }

    @GetMapping("/api/notifications")
    public Map<String, Object> notifications(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.notifications(authorization);
    }

    @GetMapping("/api/audit-logs")
    public Map<String, Object> auditLogs(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.auditLogs(authorization);
    }

    @GetMapping("/api/admin/accounts")
    public Map<String, Object> adminListAccounts(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return service.adminListAccounts(authorization);
    }

    @PostMapping("/api/admin/accounts")
    public Map<String, Object> adminCreateAccount(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                   @RequestBody Map<String, Object> body) {
        return service.adminCreateAccount(authorization, body);
    }

    @PostMapping("/api/admin/accounts/update")
    public Map<String, Object> adminUpdateAccount(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                   @RequestBody Map<String, Object> body) {
        return service.adminUpdateAccount(authorization, body);
    }

    @PostMapping("/api/admin/accounts/soft-delete")
    public Map<String, Object> adminSoftDeleteAccount(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                       @RequestBody Map<String, Object> body) {
        return service.adminSoftDeleteAccount(authorization, body);
    }

    @PostMapping("/api/admin/accounts/restore")
    public Map<String, Object> adminRestoreAccount(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                     @RequestBody Map<String, Object> body) {
        return service.adminRestoreAccount(authorization, body);
    }

    @PostMapping("/api/profile/update")
    public Map<String, Object> updateProfile(@RequestHeader(value = "Authorization", required = false) String authorization,
                                             @RequestBody Map<String, Object> body) {
        return service.updateProfile(authorization, body);
    }

    @PostMapping("/api/feedback")
    public Map<String, Object> submitFeedback(@RequestHeader(value = "Authorization", required = false) String authorization,
                                               @RequestBody Map<String, Object> body) {
        return service.submitFeedback(authorization, body);
    }

}
