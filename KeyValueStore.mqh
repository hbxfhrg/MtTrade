//+------------------------------------------------------------------+
//|                  KeyValueStore 键值存储类                         |
//+------------------------------------------------------------------+
class KeyValueStore：public CObject
{
private:
    struct SegmentArray {
        int key;
        CZigzagSegment* segments[];
    };
    
    SegmentArray m_arrays[]; // 存储线段数组
    int m_size;             // 当前存储大小
    
public:
    KeyValueStore()
    {
        ArrayResize(m_arrays, 4);
        m_size = 0;
    }
    
    // 添加或更新键值对（单个元素）
    void Set(int key, CZigzagSegment* value)
    {
        // 查找是否已存在该键
        for(int i = 0; i < m_size; i++)
        {
            if(m_arrays[i].key == key)
            {
                // 替换为单元素数组
                ArrayResize(m_arrays[i].segments, 1);
                m_arrays[i].segments[0] = value;
                return;
            }
        }
        
        // 不存在则新增
        if(m_size >= ArraySize(m_arrays))
        {
            ArrayResize(m_arrays, m_size + 4);
        }
        
        m_arrays[m_size].key = key;
        ArrayResize(m_arrays[m_size].segments, 1);
        m_arrays[m_size].segments[0] = value;
        m_size++;
    }

    // 添加或更新键值对（整个数组）
    void SetArray(int key, CZigzagSegment* &array[])
    {
        // 查找是否已存在该键
        for(int i = 0; i < m_size; i++)
        {
            if(m_arrays[i].key == key)
            {
                // 复制数组
                ArrayResize(m_arrays[i].segments, ArraySize(array));
                for(int j = 0; j < ArraySize(array); j++)
                {
                    m_arrays[i].segments[j] = array[j];
                }
                return;
            }
        }
        
        // 不存在则新增
        if(m_size >= ArraySize(m_arrays))
        {
            ArrayResize(m_arrays, m_size + 4);
        }
        
        m_arrays[m_size].key = key;
        ArrayResize(m_arrays[m_size].segments, ArraySize(array));
        for(int j = 0; j < ArraySize(array); j++)
        {
            m_arrays[m_size].segments[j] = array[j];
        }
        m_size++;
    }
    
    // 获取数组
    bool GetArray(int key, CZigzagSegment* &array[])
    {
        for(int i = 0; i < m_size; i++)
        {
            if(m_arrays[i].key == key)
            {
                ArrayResize(array, ArraySize(m_arrays[i].segments));
                for(int j = 0; j < ArraySize(m_arrays[i].segments); j++)
                {
                    array[j] = m_arrays[i].segments[j];
                }
                return true;
            }
        }
        return false;
    }
    
    // 获取值
    bool Get(int key, CZigzagSegment* &value)
    {
        for(int i = 0; i < m_size; i++)
        {
            if(m_arrays[i].key == key && ArraySize(m_arrays[i].segments) > 0)
            {
                value = m_arrays[i].segments[0];
                return true;
            }
        }
        return false;
    }
    
    // 检查键是否存在
    bool ContainsKey(int key)
    {
        for(int i = 0; i < m_size; i++)
        {
            if(m_arrays[i].key == key) return true;
        }
        return false;
    }
    
    // 清空缓存
    void Clear()
    {
        m_size = 0;
    }
};