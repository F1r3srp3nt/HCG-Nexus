// Minimal assertion framework for the host test runner (no XCTest on Linux).
#import <Foundation/Foundation.h>
#include <math.h>

extern int HCGTestFailures;
extern int HCGTestChecks;
extern const char *HCGCurrentTest;

#define HCG_CHECK(cond, ...) do { \
    HCGTestChecks++; \
    if (!(cond)) { \
        HCGTestFailures++; \
        fprintf(stderr, "  FAIL [%s] %s:%d: %s — ", HCGCurrentTest, __FILE__, __LINE__, #cond); \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } \
} while (0)

#define HCG_CHECK_EQ_INT(a, b) HCG_CHECK((long)(a) == (long)(b), "expected %ld, got %ld", (long)(b), (long)(a))
#define HCG_CHECK_EQ_STR(a, b) HCG_CHECK([(a) isEqualToString:(b)], "expected '%s', got '%s'", [[(b) description] UTF8String], [[(a) description] UTF8String])
#define HCG_CHECK_NEAR(a, b, eps) HCG_CHECK(fabs((double)(a) - (double)(b)) <= (eps), "expected %.4f, got %.4f", (double)(b), (double)(a))



// Test suites (each defined in its own file).
void HCGRunSettingsTests(void);
void HCGRunActionTests(void);
void HCGRunWorkspaceStoreTests(void);
void HCGRunRecentsTests(void);
void HCGRunSearchTests(void);
void HCGRunIntegrationTests(void);
void HCGRunGeometryTests(void);
void HCGRunStateMachineTests(void);
void HCGRunOverlayTests(void);
void HCGRunDiagnosticsTests(void);

#define HCG_RUN(fn) do { HCGCurrentTest = #fn; fn(); } while (0)
