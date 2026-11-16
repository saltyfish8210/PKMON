package edu.pkmon.capture.web;

import edu.pkmon.capture.dto.CaptureDtos.ApiEnvelope;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.capture.service.CollectionService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 收藏查询：概览、图鉴、背包。
 *
 * <p>userId 只从 {@link CurrentUserProvider} 取得，不接受请求参数传入，
 * 因此无法通过改参数读取他人收藏。
 */
@RestController
@RequestMapping("/api/v1/collection")
public class CollectionController {

    private final CollectionService collectionService;
    private final CurrentUserProvider currentUser;

    public CollectionController(CollectionService collectionService,
                               CurrentUserProvider currentUser) {
        this.collectionService = collectionService;
        this.currentUser = currentUser;
    }

    @GetMapping("/summary")
    public ApiEnvelope summary() {
        String userId = currentUser.currentUserId();
        return ApiEnvelope.ok(collectionService.summary(userId));
    }

    /** 图鉴：目录全部种类 + 本人收录情况（含未解锁占位）。 */
    @GetMapping("/dex")
    public ApiEnvelope dex() {
        String userId = currentUser.currentUserId();
        return ApiEnvelope.ok(collectionService.dex(userId));
    }

    /** 背包：本人实际持有的种类与数量，按最近收录时间倒序。 */
    @GetMapping("/bag")
    public ApiEnvelope bag() {
        String userId = currentUser.currentUserId();
        return ApiEnvelope.ok(collectionService.bag(userId));
    }
}
