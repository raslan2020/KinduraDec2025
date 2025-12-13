#!/usr/bin/env python3
"""
Simple test script for the LiveKit agent
Tests the core components without requiring LiveKit cloud connection
"""

import asyncio
import os
from dotenv import load_dotenv
from livekit.plugins import openai, deepgram

# Load environment variables
load_dotenv()

async def test_openai():
    """Test OpenAI LLM integration"""
    print("\n=== Testing OpenAI LLM ===")
    try:
        llm = openai.LLM(model="gpt-4o-mini")
        print("✅ OpenAI LLM initialized successfully")
        
        # Test a simple completion
        response = await llm.agenerate(
            "Say 'Hello, Kindura AI is working!' in exactly 5 words"
        )
        print(f"✅ LLM Response: {response}")
        return True
    except Exception as e:
        print(f"❌ OpenAI LLM Error: {e}")
        return False

async def test_deepgram():
    """Test Deepgram STT integration"""
    print("\n=== Testing Deepgram STT ===")
    try:
        stt = deepgram.STT(language="en")
        print("✅ Deepgram STT initialized successfully")
        return True
    except Exception as e:
        print(f"❌ Deepgram STT Error: {e}")
        return False

async def test_api_connection():
    """Test connection to local Django API"""
    print("\n=== Testing Local API Connection ===")
    import aiohttp
    
    api_url = os.getenv("API_BASE_URL", "http://localhost:8000/api")
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{api_url}/") as response:
                if response.status == 200:
                    print(f"✅ Connected to API at {api_url}")
                    return True
                else:
                    print(f"⚠️ API returned status {response.status}")
                    return False
    except Exception as e:
        print(f"❌ Cannot connect to API: {e}")
        return False

async def main():
    """Run all tests"""
    print("=" * 50)
    print("Kindura LiveKit Agent Test Suite")
    print("=" * 50)
    
    # Check environment variables
    print("\n=== Environment Variables ===")
    env_vars = {
        "LIVEKIT_URL": os.getenv("LIVEKIT_URL"),
        "LIVEKIT_API_KEY": os.getenv("LIVEKIT_API_KEY"),
        "OPENAI_API_KEY": "***" if os.getenv("OPENAI_API_KEY") else None,
        "DEEPGRAM_API_KEY": "***" if os.getenv("DEEPGRAM_API_KEY") else None,
        "API_BASE_URL": os.getenv("API_BASE_URL")
    }
    
    for key, value in env_vars.items():
        status = "✅" if value else "❌"
        print(f"{status} {key}: {value if value else 'NOT SET'}")
    
    # Run tests
    results = []
    results.append(await test_api_connection())
    results.append(await test_openai())
    results.append(await test_deepgram())
    
    # Summary
    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"✅ All {total} tests passed!")
        print("\nThe LiveKit agent components are working correctly.")
        print("To run the full agent:")
        print("  - For development: python agent.py dev")
        print("  - For console test: python agent.py console")
        print("  - For production: python agent.py start")
    else:
        print(f"⚠️ {passed}/{total} tests passed")
        print("\nSome components need attention.")
        print("Check the error messages above for details.")

if __name__ == "__main__":
    asyncio.run(main())