#include <array>
#include <cstdint>

#include <catch2/catch_test_macros.hpp>
#include <NyuTestUtil.hpp>

#include <VLoopback_tb.h>

enum ADDRS {
  RX_STATUS = 0,
  RX_DATA = 4,
  TX_STATUS = 8,
  TX_DATA = 12,
};

static void reset(VLoopback_tb& lb, nyu::tracer<VLoopback_tb>& trace) {
  lb.rate = 5207;
  lb.wen = 0;
  lb.ren = 0;
  lb.valid = 0;
  lb.syncReset = 0;
  nyu::reset(trace);
}

static void send(auto& lb, nyu::tracer<VLoopback_tb>& trace, std::uint8_t val) {
  lb.data_tx = val;
  lb.valid = 1;
  nyu::tick(trace);
  lb.valid = 0;
}

union RxStatus {
  std::uint32_t data;
  struct {
    std::uint8_t avail : 1;
    std::uint8_t err : 1;
    std::uint8_t _reserved;
    std::uint16_t rate;
  } __attribute__((packed));
};

union TxStatus {
  std::uint32_t data;
  struct {
    std::uint8_t done : 1;
    std::uint8_t _reserved;
    std::uint16_t rate;
  } __attribute__((packed));
};

TEST_CASE("VLoopback_tb, reset") {
  auto& lb {nyu::getDUT<VLoopback_tb>()};
  nyu::tracer trace {lb, "loopback_reset.fst"};
  reset(lb, trace);

  lb.ren = 1;
  lb.addr = TX_STATUS;
  nyu::tick(trace);

  TxStatus tx_status {.data {lb.rdata}};
  REQUIRE(tx_status.rate == 5207);
}

union RxData {
  std::uint32_t data;
  struct {
    std::array<std::uint8_t, 3> rBuf;
    std::uint8_t rCount;
  };
};

TEST_CASE("VLoopback_tb, rx") {
  auto& lb {nyu::getDUT<VLoopback_tb>()};
  nyu::tracer trace {lb, "loopback_rx.fst"};
  reset(lb, trace);

  constexpr std::array<std::uint8_t, 3> seq {0xAA, 0xBB, 0xCC};
  send(lb, trace, seq[0]);

  for(unsigned i {1}; i < seq.size();) {
    if(lb.done_tx)
      send(lb, trace, seq[i++]);
    else
      nyu::tick(trace);
  }

  while(!lb.done_tx)
    nyu::tick(trace);

  lb.ren = 1;
  lb.addr = RX_DATA;
  nyu::tick(trace);

  RxData q {.data {lb.rdata}};

  REQUIRE(q.rBuf == std::array<std::uint8_t, 3> {0xAA, 0xBB, 0xCC});
  REQUIRE(q.rCount == 3);
}

union TxData {
  std::uint32_t data;
  struct {
    std::array<std::uint8_t, 3> wBuf;
    std::uint8_t wCount;
  };
};

TEST_CASE("VLoopback_tb, tx") {
  auto& lb {nyu::getDUT<VLoopback_tb>()};
  nyu::tracer trace {lb, "loopback_tx.fst"};
  reset(lb, trace);

  TxData q {
      .wBuf = {0xAA, 0xBB, 0xCC},
      .wCount = 3,
  };

  lb.wen = 1;
  lb.strobe = 0xF;
  lb.addr = TX_DATA;
  lb.wdata = q.data;

  nyu::tick(trace);

  lb.wen = 0;

  while(!lb.done_rx)
    nyu::tick(trace);
  REQUIRE(lb.data_rx == 0xAA);

  nyu::tick(trace);

  while(!lb.done_rx)
    nyu::tick(trace);
  REQUIRE(lb.data_rx == 0xBB);

  nyu::tick(trace);

  while(!lb.done_rx)
    nyu::tick(trace);
  REQUIRE(lb.data_rx == 0xCC);

  lb.addr = TX_STATUS;
  lb.ren = 1;
  nyu::tick(trace, 5046);

  REQUIRE((lb.rdata & 1) == 1);
}
