//+------------------------------------------------------------------+
//|                                             CXVirtualPricer.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.0] Deterministic Virtual Price Generator for Self-Testing     |
//+------------------------------------------------------------------+
#ifndef CX_VIRTUAL_PRICER_MQH
#define CX_VIRTUAL_PRICER_MQH

#include <Object.mqh>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/**
 * @class CXPRNG
 * @brief 완전 결정론적 의사 난수 생성기 (테스트 결과 재현성 보장)
 */
class CXPRNG {
private:
    uint m_seed;
public:
    CXPRNG(uint seed = 12345) : m_seed(seed) {}
    
    void Seed(uint seed) { m_seed = seed; }
    
    /**
     * @brief 0.0 ~ 1.0 사이의 실수 난수 생성 (LCG 알고리즘)
     */
    double NextDouble() {
        m_seed = m_seed * 1664525 + 1013904223;
        return (double)m_seed / 4294967296.0;
    }
    
    /**
     * @brief Box-Muller 변환을 사용한 표준 정규 분포 난수 생성
     */
    double NextNormal() {
        double u1 = NextDouble();
        double u2 = NextDouble();
        if(u1 < 1e-9) u1 = 1e-9;
        return MathSqrt(-2.0 * MathLog(u1)) * MathCos(2.0 * M_PI * u2);
    }
};

/**
 * @class CXVirtualPricer
 * @brief GBM, OU, Trend+Spike 모델을 처리하는 결정론적 가격 시뮬레이터
 */
class CXVirtualPricer : public CObject {
private:
    string   m_symbol;
    string   m_model;
    double   m_currentPrice;
    int      m_spreadPoints;
    double   m_point;
    
    // GBM Parameters
    double   m_drift;
    double   m_volatility;
    
    // OU Parameters
    double   m_theta;
    double   m_meanPrice;
    
    // Trend + Spike Parameters
    double   m_trendSlope;
    double   m_jumpProb;
    double   m_jumpMean;
    double   m_jumpStd;
    
    CXPRNG   m_prng;

public:
    CXVirtualPricer(string symbol, double pointVal) 
        : m_symbol(symbol), m_model("GBM"), m_currentPrice(1.0950), m_spreadPoints(2), m_point(pointVal),
          m_drift(0.0), m_volatility(0.0), m_theta(0.0), m_meanPrice(1.0950), m_trendSlope(0.0),
          m_jumpProb(0.0), m_jumpMean(0.0), m_jumpStd(0.0) {
        m_prng.Seed(12345);
    }
    
    virtual ~CXVirtualPricer() {}
    
    /**
     * @brief 모델 기본 및 스프레드 정보 초기화
     */
    void InitModel(string model, double startPrice, int spreadPts) {
        m_model = model;
        m_currentPrice = startPrice;
        m_spreadPoints = spreadPts;
        PrintFormat("[PRICER] Model: %s, StartPrice: %.5f, SpreadPts: %d", m_model, m_currentPrice, m_spreadPoints);
    }
    
    void SetGBM(double drift, double volatility) {
        m_drift = drift;
        m_volatility = volatility;
    }
    
    void SetOU(double theta, double meanPrice, double volatility) {
        m_theta = theta;
        m_meanPrice = meanPrice;
        m_volatility = volatility;
    }
    
    void SetTrendSpike(double slope, double jumpProb, double jumpMean, double jumpStd) {
        m_trendSlope = slope;
        m_jumpProb = jumpProb;
        m_jumpMean = jumpMean;
        m_jumpStd = jumpStd;
    }
    
    /**
     * @brief 수동 가격 덮어쓰기 (TCL MARKET: price=... 대응)
     */
    void OverridePrice(double price) {
        m_currentPrice = price;
        PrintFormat("[PRICER] Price Override: %.5f", m_currentPrice);
    }
    
    double GetCurrentPrice() const { return m_currentPrice; }
    
    /**
     * @brief 스프레드를 적용한 Bid 가격 반환
     */
    double GetBid() const { 
        return m_currentPrice - (m_spreadPoints * m_point) / 2.0; 
    }
    
    /**
     * @brief 스프레드를 적용한 Ask 가격 반환
     */
    double GetAsk() const { 
        return m_currentPrice + (m_spreadPoints * m_point) / 2.0; 
    }
    
    /**
     * @brief 1 가상 틱만큼 모델 가격을 전진
     */
    double GenerateNextPrice() {
        if(m_model == "GBM") {
            double epsilon = m_prng.NextNormal();
            // Euler-Maruyama: S_t+1 = S_t * exp((drift - 0.5*vol^2)*dt + vol*epsilon*sqrt(dt))
            double exponent = m_drift - 0.5 * m_volatility * m_volatility + m_volatility * epsilon;
            m_currentPrice = m_currentPrice * MathExp(exponent);
        }
        else if(m_model == "OU") {
            double epsilon = m_prng.NextNormal();
            // dx = theta * (mean - x) * dt + vol * epsilon * sqrt(dt)
            m_currentPrice = m_currentPrice + m_theta * (m_meanPrice - m_currentPrice) + m_volatility * epsilon;
        }
        else if(m_model == "TREND_SPIKE" || m_model == "TREND") {
            double jump = 0.0;
            if(m_jumpProb > 0.0 && m_prng.NextDouble() < m_jumpProb) {
                jump = m_jumpMean + m_jumpStd * m_prng.NextNormal();
            }
            m_currentPrice = m_currentPrice + m_trendSlope + jump;
        }
        
        return m_currentPrice;
    }
};

#endif
